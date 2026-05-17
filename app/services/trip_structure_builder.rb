# Asks the configured AI prompt (slug `trip_structure.v1`, admin-editable)
# for a structured trip plan in one shot: days[].activities[] (with lat/lng
# + addresses), a packing/preparation checklist (before_trip + per-day +
# per-activity items), and a one-paragraph "why you'll love it" pitch.
#
# Returned as a plain Hash with string keys, ready to be persisted into
# TripDay / Activity / ChecklistItem records and Trip#excitement_pitch.
# Falls back to a deterministic skeleton when the AI call fails so trip
# creation never fails outright.
class TripStructureBuilder
  PROMPT_SLUG = "trip_structure.v1".freeze
  ACCENTS = TripDay::ACCENTS

  def self.call(...)
    new(...).call
  end

  def initialize(destination:, origin: nil, start_date:, end_date:, people: [], highlights: [], transport_mode: nil)
    @destination = destination.to_s.strip
    @origin = origin.to_s.strip
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @people = people || []
    @highlights = highlights || []
    @transport_mode = transport_mode.to_s.presence
  end

  def call
    result = Ai::Caller.call(slug: PROMPT_SLUG, variables: prompt_vars)
    parsed = result.json
    return fallback unless parsed.is_a?(Hash)
    coerce_shape(parsed)
  rescue => e
    Rails.logger.warn("[TripStructureBuilder] #{e.class}: #{e.message}")
    fallback
  end

  private

  def parse_date(d)
    return d if d.is_a?(Date)
    Date.parse(d.to_s)
  rescue ArgumentError
    Date.current
  end

  def prompt_vars
    {
      destination: @destination,
      origin: @origin,
      start_date_label: @start_date.strftime("%A %b %-d, %Y"),
      end_date_label: @end_date.strftime("%A %b %-d, %Y"),
      day_count: day_count,
      transport_mode: @transport_mode,
      people: @people.map { |p| { name: p[:name], age: p[:age], interests: Array(p[:interests]) } },
      highlights: @highlights.map { |h| { name: h[:name], summary: h[:summary] } }
    }
  end

  # Normalize shape so the persistence code doesn't have to defend against
  # missing keys / wrong types.
  def coerce_shape(hash)
    {
      "excitement_pitch" => hash["excitement_pitch"].to_s.strip,
      "days" => Array(hash["days"]).map.with_index do |d, i|
        {
          "label" => d["label"].presence || "day-#{i + 1}",
          "date" => d["date"].to_s,
          "title" => d["title"].to_s.presence || "Day #{i + 1}",
          "theme" => d["theme"].to_s,
          "summary" => d["summary"].to_s,
          "accent" => ACCENTS.include?(d["accent"]) ? d["accent"] : ACCENTS[i % ACCENTS.size],
          "activities" => Array(d["activities"]).map do |a|
            {
              "time_label" => a["time_label"].to_s,
              "title" => a["title"].to_s.strip,
              "location_name" => a["location_name"].to_s,
              "address" => a["address"].to_s,
              "latitude" => a["latitude"]&.to_f,
              "longitude" => a["longitude"]&.to_f,
              "famous_for" => a["famous_for"].to_s,
              "notes" => a["notes"].to_s,
              "group_label" => a["group_label"].to_s
            }
          end
        }
      end,
      "checklist" => {
        "before_trip" => Array(hash.dig("checklist", "before_trip")).map { |i| { "title" => i["title"].to_s, "category" => i["category"].to_s.presence || "General" } },
        "day" => Array(hash.dig("checklist", "day")).map { |i| { "day_label" => i["day_label"].to_s, "title" => i["title"].to_s } },
        "activity" => Array(hash.dig("checklist", "activity")).map { |i| { "day_label" => i["day_label"].to_s, "activity_label" => i["activity_label"].to_s, "title" => i["title"].to_s } }
      }
    }
  end

  def day_count
    (@end_date - @start_date).to_i + 1
  end

  def fallback
    days = (0...day_count).map do |i|
      date = @start_date + i
      {
        "label" => "day-#{i + 1}",
        "date" => date.iso8601,
        "title" => "Day #{i + 1} in #{@destination}",
        "theme" => "Explore",
        "summary" => "Plan the day with your group.",
        "accent" => ACCENTS[i % ACCENTS.size],
        "activities" => @highlights.first(3).map.with_index do |h, j|
          {
            "time_label" => [ "9:00 AM", "12:30 PM", "4:00 PM" ][j % 3],
            "title" => h[:name].to_s,
            "location_name" => h[:name].to_s,
            "address" => @destination,
            "latitude" => nil, "longitude" => nil,
            "famous_for" => h[:summary].to_s,
            "notes" => "", "group_label" => ""
          }
        end
      }
    end
    {
      "excitement_pitch" => "",
      "days" => days,
      "checklist" => {
        "before_trip" => [ { "title" => "Confirm reservations", "category" => "Logistics" }, { "title" => "Pack layers + water bottles", "category" => "Packing" } ],
        "day" => [], "activity" => []
      }
    }
  end
end
