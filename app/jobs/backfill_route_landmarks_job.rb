# Builds the trip's drive-by RouteLandmarks AFTER the plan is already viewable.
# RouteLandmarksBuilder makes its own AI call (route_landmarks.v1, Anthropic —
# the prod container has no Claude CLI, so never point it at claude_cli) and
# used to run INLINE in Trips::Assembler — dominating the build wall-clock (~3 min) even though landmarks only feed the Drive Co-Pilot and the
# road-trip-stats page, both of which degrade gracefully while empty. Pulling it
# here lets the build return the plan fast; the landmarks stream in within a
# minute or two and a Turbo refresh morphs them onto any open trip page.
#
# Idempotent: RouteLandmarksBuilder#persist! clears prior rows and rewrites, so a
# rebuild/replay just regenerates. Derives stops from the persisted activities
# (not the transient structure hash) so it works entirely post-build.
class BackfillRouteLandmarksJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip
    return if trip.origin.blank? # nothing to drive past on a fly-in / single-city trip

    stops = trip.trip_days.includes(:activities).ordered.flat_map do |day|
      day.activities.filter_map do |a|
        next unless a.latitude.present? && a.longitude.present?
        { name: a.location_name.presence || a.title, lat: a.latitude, lng: a.longitude }
      end
    end

    RouteLandmarksBuilder.call(
      destination: trip.destination, origin: trip.origin,
      transport_mode: trip.transport_mode, itinerary_stops: stops, trip: trip
    )
  rescue StandardError => e
    # Best-effort enrichment: a failure must never surface as a broken trip.
    Rails.logger.warn("[BackfillRouteLandmarksJob] trip=#{trip_id}: #{e.class}: #{e.message}")
  ensure
    trip&.broadcast_refresh_to(trip)
  end
end
