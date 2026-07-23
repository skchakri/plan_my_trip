# Assembles a "building" day-trip shell off the request thread (DayPlanBuilder is
# an AI call + per-stop Places::Seeder image lookups). Re-derives the chosen
# ideas from NearbyIdeas (cached from the suggestions page) using the slugs saved
# in trip.build_args, runs Trips::DayAssembler, flips build_status, broadcasts a
# Turbo refresh, and kicks off narration backfill. Mirrors BuildTripJob.
class BuildDayTripJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip&.building?

    args = trip.build_args || {}
    Trips::DayAssembler.call(
      trip: trip,
      ideas: chosen_ideas(trip, args),
      depart_time: args["depart_time"],
      return_time: args["return_time"]
    )
    trip.update!(build_status: "ready", build_error: nil, plan_stale_at: nil)
    BackfillTripNarrationsJob.perform_later(trip.id)
  rescue StandardError => e
    ErrorTracker.report(e, source: "BuildDayTripJob", context: { trip_id: trip_id })
    trip&.update_columns(build_status: "failed", build_error: "#{e.class}: #{e.message}".truncate(500))
  ensure
    trip&.broadcast_refresh_to(trip)
  end

  private

  # Cache hit on the same NearbyIdeas call the suggestions page already ran.
  def chosen_ideas(trip, args)
    slugs = Array(args["selected_slugs"]).map(&:to_s).reject(&:blank?).to_set
    return [] if slugs.empty?

    NearbyIdeas.call(
      anchor_label: trip.anchor_label, lat: trip.anchor_lat, lng: trip.anchor_lng,
      radius_km: trip.max_radius_km, interests: Array(trip.interests),
      user_query: args["q"].to_s, trip_date: trip.start_date.to_s
    ).select { |i| slugs.include?(i.slug) }
  end
end
