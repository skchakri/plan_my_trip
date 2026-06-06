# Generates one Activity's spoken `guide_script` via the activity_narration.v1
# prompt. Pulled OUT of the one-shot trip_structure build (where 16 inline
# narrations dominated the output tokens / latency) and run per-activity in
# BackfillTripNarrationsJob after the trip is already shown. Ai::Caller dedupes
# identical (name/location) narrations across trips, so popular stops are
# narrated once.
class ActivityNarrator
  PROMPT_SLUG = "activity_narration.v1".freeze

  # Trivial admin stops that don't warrant narration (matches the prompt's own
  # guard so we don't even spend a call).
  SKIP_TITLE = /\A\s*(check[\s-]?in|check[\s-]?out|pick up|drop off|return rental|grocery|gas stop|depart home|arrive home)/i

  def self.call(...)
    new(...).call
  end

  def initialize(activity, destination: nil)
    @activity = activity
    @destination = destination.to_s.strip.presence
  end

  # Returns the narration string, or nil (blank name / admin stop / AI error).
  def call
    name = display_name
    return nil if name.blank? || skip?

    result = Ai::Caller.call(
      slug: PROMPT_SLUG,
      trip: @activity.trip,
      variables: {
        name: name,
        location: [ @activity.address.presence, @destination ].compact.first.to_s,
        destination: @destination,
        group_label: @activity.group_label,
        famous_for: @activity.famous_for
      }
    )
    json = result.json
    text = json.is_a?(Hash) ? json["narration"] : result.text
    text.to_s.strip.presence
  rescue StandardError => e
    Rails.logger.warn("[ActivityNarrator] activity=#{@activity&.id}: #{e.class}: #{e.message}")
    nil
  end

  private

  def display_name
    (@activity.location_name.presence || @activity.title).to_s.strip
  end

  def skip?
    return true if @activity.group_label.to_s.strip.downcase == "admin"
    SKIP_TITLE.match?(@activity.title.to_s)
  end
end
