# Assembles a "building" Trip shell into a full plan off the request thread:
# the structured-itinerary + route-landmarks AI calls take minutes, so doing
# them inline in WizardController#create would block the HTTP request (and pin a
# Puma worker) for the whole time. When done it flips build_status and
# broadcasts a Turbo refresh so the trip page (subscribed via turbo_stream_from)
# reloads into the finished plan.
class BuildTripJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip&.building?

    selected_slugs = Array((trip.build_args || {})["selected_slugs"])
    Trips::Assembler.call(trip: trip, highlights: highlights_for(trip, selected_slugs))
    trip.update!(build_status: "ready", build_error: nil)
    # Narrations + route landmarks are generated separately so the plan is
    # viewable fast — they backfill into the podcast + Drive Co-Pilot over the
    # next minute (route landmarks run on the slow web-search provider).
    BackfillTripNarrationsJob.perform_later(trip.id)
    BackfillRouteLandmarksJob.perform_later(trip.id)
    BackfillTripImagesJob.perform_later(trip.id)
  rescue StandardError => e
    ErrorTracker.report(e, source: "BuildTripJob", context: { trip_id: trip_id })
    trip&.update_columns(build_status: "failed", build_error: "#{e.class}: #{e.message}".truncate(500))
  ensure
    # Turbo 8 refresh stream — the page morphs/reloads into the ready (or failed)
    # state. Nil-safe if the trip vanished.
    trip&.broadcast_refresh_to(trip)
  end

  private

  # Re-derive the chosen Highlight payloads from their slugs (cached 30 days in
  # DestinationHighlights), so we don't have to stash the full objects.
  def highlights_for(trip, slugs)
    set = Array(slugs).map(&:to_s).reject(&:blank?).to_set
    return [] if set.empty?
    DestinationHighlights.call(trip.destination)
                         .select { |h| set.include?(h.slug) }
                         .map { |h| h.to_h.symbolize_keys }
  end
end
