class RouteLandmark < ApplicationRecord
  include Discard::Model

  KINDS = %w[
    historic geological scenic cultural engineering natural
    ghost_town battlefield river_crossing pass_summit observatory tribal
  ].freeze
  SOURCES = %w[ai manual seed].freeze

  belongs_to :trip, optional: true

  validates :name, :narration, :latitude, :longitude, presence: true
  validates :kind,   inclusion: { in: KINDS }
  validates :source, inclusion: { in: SOURCES }
  validates :latitude,  numericality: { greater_than_or_equal_to: -90,  less_than_or_equal_to:  90 }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :global,  -> { where(trip_id: nil) }

  # Returns global landmarks (trip_id: nil) within `radius_m` meters of
  # ANY of the provided [lat, lng] waypoints. Used by the Drive Co-Pilot
  # to merge marquee catalog rows into a trip's stop list without
  # re-running AI. Cheap: one bounding-box query, then Haversine filter
  # in Ruby on the small candidate set.
  def self.near_route(waypoints, radius_m: 16_000)
    pairs = Array(waypoints).filter_map do |p|
      lat, lng = p.is_a?(Hash) ? [ p[:lat] || p["lat"], p[:lng] || p["lng"] ] : [ p[0], p[1] ]
      next if lat.blank? || lng.blank?
      [ lat.to_f, lng.to_f ]
    end
    return none if pairs.empty?

    lats = pairs.map(&:first)
    lngs = pairs.map(&:last)
    mid_lat = (lats.min + lats.max) / 2.0
    pad_lat = radius_m / 111_111.0
    pad_lng = radius_m / (111_111.0 * Math.cos(mid_lat * Math::PI / 180.0).abs)

    box = global.kept.where(
      latitude:  (lats.min - pad_lat)..(lats.max + pad_lat),
      longitude: (lngs.min - pad_lng)..(lngs.max + pad_lng)
    )
    box.select do |l|
      pairs.any? { |wlat, wlng| Place.haversine_m(l.latitude.to_f, l.longitude.to_f, wlat, wlng) <= radius_m }
    end
  end

  # Stable client-side id used by the Drive Co-Pilot JS to dedupe stops.
  def client_id
    "rl-#{id[0, 12]}"
  end

  # Hash shape consumed by drive_copilot_controller.js + the plan view.
  # Kept compatible with the old JSONB structure so the JS doesn't change.
  def as_drive_stop
    {
      "id" => client_id,
      "name" => name,
      "kind" => kind,
      "lat" => latitude.to_f,
      "lng" => longitude.to_f,
      "narration" => narration,
      "image_url" => image_url,
      "wikipedia_url" => wikipedia_url
    }
  end
end
