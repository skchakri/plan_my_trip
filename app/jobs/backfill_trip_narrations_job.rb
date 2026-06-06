# Orchestrates per-activity `guide_script` backfill after a trip is built, so the
# main build can return a viewable plan fast (the inline narrations used to
# dominate trip_structure's output tokens). Fans out one NarrateActivityJob per
# blank activity so they run concurrently. Idempotent: only enqueues blanks, so
# it's safe to re-run. Narrations stream into the read-aloud podcast + Drive
# Co-Pilot on the next view; both already degrade gracefully while blank.
class BackfillTripNarrationsJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip

    trip.trip_days.includes(:activities).each do |day|
      day.activities.each do |activity|
        next if activity.guide_script.present?
        NarrateActivityJob.perform_later(activity.id)
      end
    end
  end
end
