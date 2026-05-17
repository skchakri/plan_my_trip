class Trip < ApplicationRecord
  include Discard::Model

  # How the group is getting around. nil = unspecified.
  # "own_car" suppresses rental-car booking suggestions and adds vehicle
  # prep items to the checklist; "rental" / "flying" / "mixed" are
  # informational labels surfaced in the UI.
  TRANSPORT_MODES = %w[own_car rental flying mixed].freeze
  validates :transport_mode, inclusion: { in: TRANSPORT_MODES }, allow_nil: true

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

  def shared_with?(user)
    return false if user.blank?
    trip_memberships.where(user_id: user.id).exists?
  end

  def title_for(user)
    membership = trip_memberships.find_by(user_id: user&.id)
    membership&.custom_title.presence || title
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
