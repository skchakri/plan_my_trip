# Generates one activity's spoken guide_script. Fanned out (one per activity) by
# BackfillTripNarrationsJob so a trip's narrations run concurrently across Solid
# Queue workers — wall-clock ≈ the slowest single narration, not their sum.
# Idempotent: skips activities that already have a script.
class NarrateActivityJob < ApplicationJob
  queue_as :default

  def perform(activity_id)
    activity = Activity.find_by(id: activity_id)
    return if activity.nil? || activity.guide_script.present?

    narration = ActivityNarrator.call(activity, destination: activity.trip&.destination)
    activity.update_column(:guide_script, narration) if narration.present?
  end
end
