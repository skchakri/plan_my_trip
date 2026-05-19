# Shared "places" database — every named location any user has ever
# added to a trip gets a row here. Subsequent trips that include the
# same place reuse the row (no fresh Wikipedia/AI lookup), so the more
# people who plan, the richer the shared catalog gets.
#
# Find-or-seed lookup (case-insensitive name within ~500m): see
# Places::Seeder.
class Place < ApplicationRecord
  include Discard::Model

  has_many :activities, dependent: :nullify
  has_many :reviews, -> { kept.ordered }, class_name: "PlaceReview", dependent: :destroy
  belongs_to :contributed_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :slug, uniqueness: true, allow_nil: true
  before_validation :assign_slug

  # SEO-friendly URL fragment, falls back to UUID if no slug was set yet.
  def to_param
    slug.presence || id
  end

  # Public SEO route helper — Place rows are global, so the URL is stable
  # across users.
  def public_path
    slug.present? ? "/p/#{slug}" : nil
  end

  IMAGE_SOURCES = %w[wikipedia ai user google_places admin].freeze
  validates :image_source, inclusion: { in: IMAGE_SOURCES }, allow_nil: true

  KINDS = %w[
    lodging restaurant cafe trail viewpoint landmark natural geological
    historic museum park beach city town drive_segment overlook
  ].freeze
  validates :kind, inclusion: { in: KINDS }, allow_nil: true

  TIERS = %w[iconic well_known underrated hidden_gem].freeze
  validates :tier, inclusion: { in: TIERS }, allow_nil: true

  scope :iconic,      -> { kept.where(tier: "iconic") }
  scope :underrated,  -> { kept.where(tier: "underrated") }
  scope :hidden_gem,  -> { kept.where(tier: "hidden_gem") }
  scope :in_region,   ->(r) { kept.where(region: r) }

  scope :popular,    -> { kept.order(usage_count: :desc) }
  scope :verified,   -> { kept.where(verified: true) }
  scope :with_image, -> { kept.where.not(image_url: nil) }

  # Case-insensitive name lookup. Use sparingly — pair with proximity
  # in Places::Seeder so two motels with the same name in different
  # cities stay distinct.
  scope :named, ->(n) { where("lower(name) = ?", n.to_s.downcase.strip) }

  # All kept places within `radius_m` meters of (lat, lng). Uses a
  # bounded box first (cheap, index-backed), then does the Haversine
  # filter in Ruby on the small candidate set.
  scope :near, ->(lat, lng, radius_m: 500) {
    next none if lat.blank? || lng.blank?
    lat_f = lat.to_f
    lng_f = lng.to_f
    # 1 degree latitude ≈ 111_111 m. Longitude shrinks by cos(lat).
    lat_delta = radius_m / 111_111.0
    lng_delta = radius_m / (111_111.0 * Math.cos(lat_f * Math::PI / 180.0).abs)
    kept.where(latitude:  (lat_f - lat_delta)..(lat_f + lat_delta),
               longitude: (lng_f - lng_delta)..(lng_f + lng_delta))
  }

  # Returns distance in meters from this place to the given coords.
  # Used by Places::Seeder to pick the closest of several near-name
  # candidates.
  def distance_m_from(lat, lng)
    return Float::INFINITY if latitude.blank? || longitude.blank? || lat.blank? || lng.blank?
    Place.haversine_m(latitude.to_f, longitude.to_f, lat.to_f, lng.to_f)
  end

  private

  def assign_slug
    return if slug.present?
    base = (canonical_name.presence || name.to_s).parameterize
    return if base.blank?
    # Mint the UUID client-side so the slug suffix is stable on first save.
    # Without this, `id` is nil during before_validation on new records and
    # the suffix would be empty, allowing collisions on duplicate names.
    self.id ||= SecureRandom.uuid
    suffix = id.to_s.delete("-")[0, 6]
    self.slug = "#{base}-#{suffix}".gsub(/-+/, "-").chomp("-")
  end

  public

  def self.haversine_m(lat1, lng1, lat2, lng2)
    r = 6_371_000.0
    to_rad = ->(d) { d * Math::PI / 180.0 }
    dlat = to_rad.call(lat2 - lat1)
    dlng = to_rad.call(lng2 - lng1)
    a = Math.sin(dlat / 2)**2 + Math.cos(to_rad.call(lat1)) * Math.cos(to_rad.call(lat2)) * Math.sin(dlng / 2)**2
    2 * r * Math.asin(Math.sqrt(a))
  end

  # Bumps the cross-trip reference counter when an activity links to
  # this place. Caller is responsible for invoking it (we don't hook
  # Activity callbacks to avoid double-counting on updates).
  def record_usage!(by: nil)
    self.usage_count = (usage_count || 0) + 1
    self.contributed_by ||= by
    save!
  end

  # Refreshes the denormalized community rating columns from kept reviews.
  # Called from PlaceReview callbacks — keeps card-grid queries cheap by
  # avoiding a per-card AVG aggregate.
  def recompute_community_rating!
    scope = PlaceReview.where(place_id: id).kept
    count = scope.count
    avg   = count.zero? ? nil : scope.average(:rating)&.to_f&.round(2)
    update_columns(community_rating: avg, community_rating_count: count)
  end
end
