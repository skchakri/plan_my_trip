# Given a destination, dates, travelers (name/age/interests), and a list of
# selected highlights, calls the configured AI prompt (slug
# `itinerary_builder.v1`, admin-editable) to produce a polished day-by-day
# markdown itinerary that becomes the new trip's `body`.
#
# Falls back to a deterministic round-robin skeleton if the prompt is missing
# or the AI call fails, so wizard finalization is never blocked.
class ItineraryBuilder
  PROMPT_SLUG = "itinerary_builder.v1".freeze

  def self.call(...)
    new(...).call
  end

  def initialize(destination:, origin: nil, start_date:, end_date:, people: [], highlights: [])
    @destination = destination.to_s.strip
    @origin = origin.to_s.strip
    @start_date = start_date.is_a?(Date) ? start_date : Date.parse(start_date.to_s)
    @end_date = end_date.is_a?(Date) ? end_date : Date.parse(end_date.to_s)
    @people = people || []
    @highlights = highlights || []
  end

  def call
    result = Ai::Caller.call(slug: PROMPT_SLUG, variables: prompt_vars)
    text = result.text.to_s.strip
    text.presence || fallback_markdown
  rescue => e
    Rails.logger.warn("[ItineraryBuilder] #{e.class}: #{e.message}")
    fallback_markdown
  end

  private

  def prompt_vars
    {
      destination: @destination,
      origin: @origin,
      start_date_label: @start_date.strftime("%A %b %-d, %Y"),
      end_date_label: @end_date.strftime("%A %b %-d, %Y"),
      day_count: day_count,
      people: @people.map { |p| { name: p[:name], age: p[:age], interests: Array(p[:interests]) } },
      highlights: @highlights.map { |h| { name: h[:name], summary: h[:summary] } }
    }
  end

  def day_count
    (@end_date - @start_date).to_i + 1
  end

  def fallback_markdown
    lines = []
    lines << "## Overview"
    lines << "#{day_count}-day trip to **#{@destination}** for #{@people.size > 0 ? @people.map { |p| p[:name] }.join(', ') : 'the group'}."
    lines << ""

    days = day_count
    buckets = Array.new(days) { [] }
    @highlights.each_with_index { |h, i| buckets[i % days] << h }

    (0...days).each do |i|
      date = @start_date + i
      lines << "## Day #{i + 1} — #{date.strftime('%A, %b %-d')}"
      buckets[i].each do |h|
        line = "- **#{h[:name]}**"
        line += " — #{h[:summary]}" if h[:summary].present?
        lines << line
      end
      lines << "- Evening: dinner + downtime"
      lines << ""
    end

    lines << "## Tips"
    lines << "- Book hotels close to the main cluster of sights"
    lines << "- Pack layers — desert/mountain weather swings a lot"
    lines << "- Buy attraction tickets online to skip lines"
    lines.join("\n")
  end
end
