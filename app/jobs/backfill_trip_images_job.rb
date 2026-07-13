# Resolves per-stop photos AFTER the plan is viewable. Each Wikipedia/Wikimedia
# lookup is ~2s and a trip build touches ~16 places, so Trips::Assembler creates
# the Place rows with `defer_image: true` (no inline lookup) and enqueues this to
# fill them off the critical path. Activity#hero_image_url reads place.image_url
# live, so a photo appears on the next render; a final broadcast_refresh morphs
# the resolved photos onto any open plan. This is the "images can respond slowly"
# path — the itinerary text is already correct and complete without it.
#
# Idempotent: only touches places still missing an image, so a re-run (or a
# rebuild) is safe and cheap. Best-effort throughout — a lookup miss just leaves
# that card photo-less (the map still renders).
class BackfillTripImagesJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip

    # Distinct places across the trip's activities that still lack a photo.
    places = trip.trip_days.includes(activities: :place).flat_map(&:activities)
                 .filter_map(&:place).uniq(&:id)
                 .reject { |p| p.image_url.present? }
    return if places.empty?

    filled = 0
    places.each do |place|
      next if place.name.blank?
      url = PlaceImageLookup.call(place.name, lat: place.latitude&.to_f, lng: place.longitude&.to_f)
      next if url.blank?
      place.update_columns(
        image_url: url,
        image_source: "wikipedia",
        image_attribution: "Photo from Wikipedia / Wikimedia Commons"
      )
      filled += 1
    rescue StandardError => e
      Rails.logger.warn("[BackfillTripImagesJob] place=#{place.id}: #{e.class}: #{e.message}")
    end

    trip.broadcast_refresh_to(trip) if filled.positive?
  end
end
