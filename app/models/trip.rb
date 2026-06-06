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
  validates :transport_mode, inclusion: { in: TRANSPORT_MODES }, allow_nil: true

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

  belongs_to :owner, class_name: "User"
  has_many :trip_memberships, dependent: :destroy
  has_many :members, through: :trip_memberships, source: :user
  has_many :trails, dependent: :destroy
  accepts_nested_attributes_for :trails, allow_destroy: true, reject_if: :all_blank
  has_many :invitations, class_name: "TripInvitation", dependent: :destroy
  has_many :checklist_items, dependent: :destroy
  has_many :booking_claims, dependent: :destroy
  has_many :trip_days, -> { ordered }, dependent: :destroy
  has_many :route_landmarks, -> { kept.ordered }, dependent: :destroy
  has_many :people, -> { ordered }, dependent: :destroy
  accepts_nested_attributes_for :people, allow_destroy: true, reject_if: ->(attrs) { attrs[:name].to_s.strip.blank? }

  has_many_attached :documents

  validates :title, presence: true
  validate :end_after_start

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
