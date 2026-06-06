# Renders a Trip#body markdown narrative from the *already-built* structured
# plan (TripStructureBuilder output). Replaces the separate ItineraryBuilder AI
# call: the structured days are the source of truth, so the prose body is now
# derived from them for free instead of paying a second (slow) LLM call that
# covered the same itinerary.
class MarkdownItinerary
  def self.from_structure(structure, destination:, people: [])
    new(structure, destination: destination, people: people).to_markdown
  end

  def initialize(structure, destination:, people: [])
    @structure = structure || {}
    @destination = destination.to_s.strip
    @people = Array(people)
  end

  def to_markdown
    lines = []
    lines << "## Overview"
    lines << overview_sentence
    pitch = @structure["excitement_pitch"].to_s.strip
    lines << "" << pitch if pitch.present?
    lines << ""

    Array(@structure["days"]).each_with_index do |day, i|
      lines.concat(day_section(day, i))
    end

    lines.join("\n").strip
  end

  private

  def overview_sentence
    who = @people.any? ? @people.filter_map { |p| (p[:name] || p["name"]).to_s.strip.presence }.to_sentence : "the group"
    count = Array(@structure["days"]).size
    dest = @destination.presence || "your destination"
    "#{count}-day trip to **#{dest}**#{who.present? ? " for #{who}" : ''}."
  end

  def day_section(day, index)
    out = []
    heading = [ day["title"].presence || "Day #{index + 1}", format_date(day["date"]) ].compact.join(" — ")
    out << "## #{heading}"
    summary = day["summary"].to_s.strip
    out << summary if summary.present?
    Array(day["activities"]).each do |a|
      out << activity_line(a)
    end
    out << ""
    out
  end

  def activity_line(activity)
    title = activity["title"].to_s.strip.presence || activity["location_name"].to_s.strip.presence || "Activity"
    parts = [ "**#{title}**" ]
    parts.unshift(activity["time_label"].to_s.strip) if activity["time_label"].to_s.strip.present?
    detail = activity["famous_for"].to_s.strip.presence || activity["notes"].to_s.strip.presence
    line = "- #{parts.join(' · ')}"
    line += " — #{detail}" if detail.present?
    line
  end

  def format_date(raw)
    return nil if raw.to_s.strip.blank?
    Date.parse(raw.to_s).strftime("%A, %b %-d")
  rescue ArgumentError
    nil
  end
end
