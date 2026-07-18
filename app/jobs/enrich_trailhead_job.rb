class EnrichTrailheadJob < ApplicationJob
  queue_as :default

  # Off-request geocode + elevation lookup for one trail. Silently no-ops if the
  # trail was deleted before the job ran.
  def perform(trail_id)
    trail = Trail.find_by(id: trail_id)
    return unless trail

    Trails::TrailheadEnricher.call(trail)
  end
end
