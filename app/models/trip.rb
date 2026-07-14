class Trip < ApplicationRecord
  include Discard::Model

  # Public read-only share link. Token is minted lazily by #enable_share_link!
  # so unshared trips stay invisible. Revocation flips share_revoked_at —
  # the same URL re-activates on re-enable; rotate with #regenerate_share_token!.
  SHARE_TOKEN_BYTES = 27 # 216 bits, ~36 URL-safe chars

  # How the group is getting around. nil = unspecified.
  # "own_car" suppresses rental-car booking suggestions and adds vehicle
  # prep items to the checklist; "rental" / "flying" / "mixed" are
  # informational labels surfaced in the UI.
  TRANSPORT_MODES = %w[own_car rental flying mixed].freeze
  # allow_blank (not allow_nil): the trip form's "No preference" option submits
  # "" rather than nil, so allow_nil alone rejected an unspecified mode.
  validates :transport_mode, inclusion: { in: TRANSPORT_MODES }, allow_blank: true

  # Human labels for TRANSPORT_MODES, shared by the wizard summary/review and
  # any other UI that displays the mode.
  TRANSPORT_MODE_LABELS = {
    "own_car" => "Driving — own car",
    "rental"  => "Driving — rental car",
    "flying"  => "Flying",
    "mixed"   => "Fly + drive"
  }.freeze

  # Traveler-mandated anchors from the wizard ("Disneyland — 2 days",
  # "a beach day"). Hard constraints for TripStructureBuilder: every entry
  # must appear in the plan, honoring any stated duration.
  MUST_INCLUDES_MAX = 12

  def must_includes=(value)
    super(Array(value).map { |v| v.to_s.strip }.reject(&:blank?).uniq.first(MUST_INCLUDES_MAX))
  end

  # Self-declared fuel economy (mpg) for the group's own car. Feeds the
  # road-trip fuel + drive-time estimator (RoadTripEstimator). Nullable;
  # a default is used (and labelled an estimate) when blank.
  validates :vehicle_mpg,
            numericality: { greater_than: 0, less_than_or_equal_to: 200 },
            allow_nil: true

  # True when the group is driving their own car — gates the road-trip stats
  # card and suppresses rental-car booking suggestions (see BookingLinks).
  def own_car?
    transport_mode == "own_car"
  end

  # Planning levers fed to TripStructureBuilder so the itinerary honors the
  # group's style, not just where/when/who.
  PACES = %w[relaxed balanced packed].freeze
  BUDGETS = %w[shoestring moderate comfortable luxury].freeze
  validates :pace, inclusion: { in: PACES }, allow_blank: true
  validates :budget, inclusion: { in: BUDGETS }, allow_blank: true

  # Async build lifecycle. New wizard trips are persisted as a shell in
  # "building" while BuildTripJob assembles days/activities/checklist off the
  # request; it flips to "ready" (or "failed") and broadcasts a Turbo refresh.
  # Existing + day-trip + manually-created trips default to "ready".
  BUILD_STATUSES = %w[building ready failed].freeze
  validates :build_status, inclusion: { in: BUILD_STATUSES }
  scope :building, -> { where(build_status: "building") }

  def building?
    build_status == "building"
  end

  def build_failed?
    build_status == "failed"
  end

  # Maps a raw build_error into a friendly { title:, hint: } so the failure page
  # can guide recovery instead of dumping a stack-trace class name. The raw
  # error stays available (shown collapsed) for debugging.
  def build_failure_summary
    err = build_error.to_s
    case err
    when /geocod|coordinate|anchor|nominatim|not found|no results|0 results|blank destination/i
      { title: "We couldn't pin that destination",
        hint: "Try a more specific place — e.g. “Las Vegas, NV” instead of “Vegas”, or add a state/country." }
    when /timeout|timed out|etimedout|econnrefused|net::|faraday|socket|503|502|504|429|rate.?limit|overloaded/i
      { title: "Our research service is busy",
        hint: "This is usually temporary — wait a few seconds and try again." }
    when /json|parse|unexpected token|keyerror|nomethoderror|missing key|undefined method|nil/i
      { title: "The AI returned something we couldn't use",
        hint: "Trying again almost always fixes this — the next response is usually clean." }
    else
      { title: "We couldn't finish this plan",
        hint: "Your trip is saved. Try building it again, or start a blank plan and fill it in yourself." }
    end
  end

  belongs_to :owner, class_name: "User"
  has_many :trip_memberships, dependent: :destroy
  has_many :members, through: :trip_memberships, source: :user
  has_many :trails, dependent: :destroy
  accepts_nested_attributes_for :trails, allow_destroy: true, reject_if: :all_blank
  has_many :invitations, class_name: "TripInvitation", dependent: :destroy
  has_many :checklist_items, dependent: :destroy
  has_many :booking_claims, dependent: :destroy
  has_many :reservations, -> { kept.ordered }, dependent: :destroy
  has_many :trip_days, -> { ordered }, dependent: :destroy
  has_many :route_landmarks, -> { kept.ordered }, dependent: :destroy
  has_many :people, -> { ordered }, dependent: :destroy
  accepts_nested_attributes_for :people, allow_destroy: true, reject_if: ->(attrs) { attrs[:name].to_s.strip.blank? }

  has_many_attached :documents

  # Live collaborative editing: any trip create/update/destroy broadcasts a
  # Turbo 8 *refresh* to this trip's own stream (the one `turbo_stream_from
  # @trip` subscribes to on trips/show). Subscribers morph the page in place —
  # no manual reload. Default is async (broadcast_refresh_later → Solid Queue),
  # and Turbo debounces/coalesces bursts. Build-step bumps use update_columns
  # (no callbacks) so the spinner stays driven by the targeted progress
  # broadcast; the failure path likewise stays on BuildTripJob's explicit
  # broadcast_refresh_to (update_columns skips this callback).
  broadcasts_refreshes

  # Content types accepted for trip-level document uploads. Anything else
  # (notably text/html and image/svg+xml, which can carry scripts) is rejected
  # before attach by AttachmentFiltering.
  DOCUMENT_CONTENT_TYPES = %w[
    application/pdf image/png image/jpeg image/webp image/heic image/heif text/plain
  ].freeze

  validates :title, presence: true
  validate :end_after_start
  # User-supplied link targets rendered as hrefs — restrict to http(s) so a
  # javascript: URI can't become a stored XSS on the plan/checklist pages.
  validates :pwa_plan_url, :pwa_packing_url,
            format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" },
            allow_blank: true

  after_create :ensure_owner_membership

  scope :ordered, -> { order(start_date: :asc, created_at: :desc) }
  scope :day_trips,   -> { where(day_trip: true) }
  scope :multi_day,   -> { where(day_trip: false) }

  # Eager-load every association that `#cover_image_url` walks. Callers
  # iterating Trips for the dashboard MUST use this — without it the
  # cover lookup N+1s across activities + photos + places + landmarks.
  scope :with_cover_data, -> {
    includes(
      :route_landmarks,
      trip_days: { activities: [ { photos_attachments: :blob }, :place ] }
    )
  }

  def day_trip?
    self[:day_trip] == true
  end

  def interests=(value)
    super(Array(value).map { |i| i.to_s.strip }.reject(&:blank?).uniq)
  end

  def shared_with?(user)
    return false if user.blank?
    trip_memberships.where(user_id: user.id).exists?
  end

  # Per-user role string ("owner"/"editor"/"member") or nil if no access.
  def role_for(user)
    return nil if user.blank?
    return "owner" if owner_id == user.id
    trip_memberships.find_by(user_id: user.id)&.role
  end

  # Owners and editors may change the plan (itinerary, days, activities,
  # checklist). Plain members can collaborate but not edit.
  def editable_by?(user)
    return false if user.blank?
    return true if owner_id == user.id
    trip_memberships.where(user_id: user.id, role: %w[owner editor]).exists?
  end

  def share_link_active?
    share_token.present? && share_revoked_at.nil?
  end

  def enable_share_link!
    update!(
      share_token:      share_token.presence || SecureRandom.urlsafe_base64(SHARE_TOKEN_BYTES),
      share_revoked_at: nil
    )
  end

  def disable_share_link!
    update!(share_revoked_at: Time.current)
  end

  def regenerate_share_token!
    update!(
      share_token:      SecureRandom.urlsafe_base64(SHARE_TOKEN_BYTES),
      share_revoked_at: nil
    )
  end

  # Per-trip email address travelers forward hotel/flight/car confirmations to.
  # The token is minted lazily on first read (mirrors share_token) and kept
  # separate from share_token so revoking the public link never breaks import.
  # Address shape: trip-<inbox_token>@<INBOUND_EMAIL_DOMAIN>.
  INBOX_TOKEN_BYTES = 18 # 144 bits, ~24 URL-safe chars

  def forwarding_address
    "trip-#{ensure_inbox_token!}@#{self.class.inbound_email_domain}"
  end

  def ensure_inbox_token!
    return inbox_token if inbox_token.present?
    # update_column, not update!: this runs lazily inside GET renders, and a
    # validation failure on unrelated legacy columns must not 500 the page.
    self.inbox_token = SecureRandom.urlsafe_base64(INBOX_TOKEN_BYTES)
    update_column(:inbox_token, inbox_token) if persisted?
    inbox_token
  end

  def self.inbound_email_domain
    AppSetting.get("INBOUND_EMAIL_DOMAIN").presence || "inbound.wanderply.com"
  end

  def title_for(user)
    membership = trip_memberships.find_by(user_id: user&.id)
    membership&.custom_title.presence || title
  end

  # Cover image for the trip — first activity hero photo across all days,
  # falling back to the first route landmark image, then nil. Iterating a
  # collection of trips? Use `Trip.with_cover_data` to preload associations,
  # otherwise this N+1s on activities + photos + places + landmarks.
  def cover_image_url
    @cover_image_url ||= begin
      hit = trip_days.flat_map(&:activities).find { |a| a.hero_image_url.present? }
      hit&.hero_image_url || route_landmarks.find { |l| l.image_url.present? }&.image_url
    end
  end

  # Stable per-trip accent palette index for gradient fallbacks. Same trip
  # always renders the same colour — no jitter between dashboard refreshes.
  def cover_palette_index
    (id.to_s.bytes.sum % 7)
  end

  def nights
    return nil if start_date.blank? || end_date.blank?
    (end_date - start_date).to_i
  end

  def days
    n = nights
    n.nil? ? nil : n + 1
  end

  def member_count
    trip_memberships.count
  end

  # Global landmarks (shared catalog) sitting within `radius_m` meters of
  # any activity or trip-scoped landmark on this trip. Drops globals
  # whose name already overlaps an activity or trip-scoped landmark to
  # avoid double-narration. Used by the plan view to enrich Drive
  # Co-Pilot stops with the marquee catalog.
  def nearby_global_landmarks(radius_m: 16_000)
    waypoints = []
    existing_names = []

    trip_days.includes(:activities).each do |day|
      day.activities.each do |a|
        next if a.latitude.blank? || a.longitude.blank?
        waypoints << [ a.latitude.to_f, a.longitude.to_f ]
        existing_names << a.location_name.to_s.downcase.strip if a.location_name.present?
        existing_names << a.title.to_s.downcase.strip if a.title.present?
      end
    end
    route_landmarks.each do |l|
      waypoints << [ l.latitude.to_f, l.longitude.to_f ]
      existing_names << l.name.to_s.downcase.strip
    end
    return RouteLandmark.none if waypoints.empty?

    names = existing_names.compact_blank.to_set
    RouteLandmark.near_route(waypoints, radius_m: radius_m).reject do |g|
      names.include?(g.name.to_s.downcase.strip)
    end
  end

  private

  def end_after_start
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "must be on or after start date") if end_date < start_date
  end

  def ensure_owner_membership
    trip_memberships.find_or_create_by!(user: owner) do |m|
      m.role = "owner"
      m.accepted_at = Time.current
    end
  end
end
