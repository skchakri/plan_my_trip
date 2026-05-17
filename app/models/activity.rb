class Activity < ApplicationRecord
  MAX_DOCUMENT_BYTES = 15.megabytes
  MAX_PHOTO_BYTES = 10.megabytes

  belongs_to :trip_day
  belongs_to :place, optional: true
  has_one :trip, through: :trip_day

  # User-uploaded photos of this stop. First attachment wins as the hero
  # so a trip member can override the Wikipedia/place image with a real
  # photo they took.
  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 800, 800 ]
  end

  has_many_attached :documents do |attachable|
    attachable.variant :preview, resize_to_limit: [ 600, 600 ]
  end

  # Visual hero: a user-uploaded photo wins, then the per-activity
  # photo_url (admin override), then the shared Place image so two
  # trips visiting the same spot reuse one canonical photo.
  def hero_image_url
    if photos.attached?
      Rails.application.routes.url_helpers.rails_blob_path(photos.first, only_path: true)
    else
      photo_url.presence || place&.image_url
    end
  end

  def hero_image_attribution
    return nil if photos.attached? || photo_url.present?
    place&.image_attribution
  end

  validates :title, presence: true
  validate :documents_within_size_limit
  validate :photos_within_size_limit

  def maps_link
    return maps_url if maps_url.present?
    return nil if address.blank?
    "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(address)}&travelmode=driving"
  end

  def uber_link
    return uber_url if uber_url.present?
    return nil if address.blank?
    "https://m.uber.com/ul/?action=setPickup&pickup=my_location&dropoff%5Bformatted_address%5D=#{CGI.escape(address)}"
  end

  def checklist_items
    trip.checklist_items.where(scope: "activity", activity_label: title)
  end

  # 2x2 OpenStreetMap tile grid centered on the activity, with the pin's
  # fractional position inside that 2x(grid)x(grid) image. Used by the plan
  # view to render an offline-cacheable map thumbnail (see service worker).
  # Returns nil when the activity has no lat/lng.
  def map_tiles(zoom: 14, grid: 2)
    return nil unless latitude && longitude

    lat_rad = latitude.to_f * Math::PI / 180.0
    n = 2.0**zoom
    x_frac = (longitude.to_f + 180.0) / 360.0 * n
    y_frac = (1.0 - Math.log(Math.tan(lat_rad) + 1.0 / Math.cos(lat_rad)) / Math::PI) / 2.0 * n
    x_origin = (x_frac - grid / 2.0).floor
    y_origin = (y_frac - grid / 2.0).floor

    tiles = []
    grid.times do |dy|
      grid.times do |dx|
        tx = x_origin + dx
        ty = y_origin + dy
        tiles << "https://tile.openstreetmap.org/#{zoom}/#{tx}/#{ty}.png"
      end
    end

    {
      tiles: tiles,
      grid: grid,
      pin_x_pct: (x_frac - x_origin) / grid * 100.0,
      pin_y_pct: (y_frac - y_origin) / grid * 100.0
    }
  end

  def packed_count
    checklist_items.where(packed: true).count
  end

  private

  def documents_within_size_limit
    documents.each do |doc|
      next unless doc.byte_size && doc.byte_size > MAX_DOCUMENT_BYTES
      errors.add(:documents, "#{doc.filename} is #{ActiveSupport::NumberHelper.number_to_human_size(doc.byte_size)}, max is #{ActiveSupport::NumberHelper.number_to_human_size(MAX_DOCUMENT_BYTES)}")
    end
  end

  def photos_within_size_limit
    photos.each do |photo|
      next unless photo.byte_size && photo.byte_size > MAX_PHOTO_BYTES
      errors.add(:photos, "#{photo.filename} is #{ActiveSupport::NumberHelper.number_to_human_size(photo.byte_size)}, max is #{ActiveSupport::NumberHelper.number_to_human_size(MAX_PHOTO_BYTES)}")
    end
  end
end
