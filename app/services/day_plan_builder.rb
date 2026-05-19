# Asks the configured AI prompt (slug `day_plan.v1`, admin-editable) for a
# single-day itinerary built around a home base + selected nearby ideas.
#
# Returns a Hash shaped just like TripStructureBuilder's output (one entry
# in `days`, a minimal `checklist`) so the existing build_days_and_activities
# and build_checklist code in the day-trip controller can reuse them
# without branching.
#
# Day-trip differences vs. multi-day:
#  - One TripDay only (label = "day-1", date = the chosen trip date)
#  - No lodging activity, no "before_trip" packing list (uses `day_of`
#    items instead — water, sun gear, snacks, fuel)
#  - Activities always start at / return to the anchor (home base)
class DayPlanBuilder
  PROMPT_SLUG = "day_plan.v1".freeze
  ACCENTS = TripDay::ACCENTS

  def self.call(...)
    new(...).call
  end

  def initialize(anchor_label:, anchor_lat:, anchor_lng:, date:, depart_time: "8:00 AM", return_time: "7:00 PM", interests: [], ideas: [], people: [])
    @anchor_label = anchor_label.to_s.strip
    @anchor_lat = anchor_lat.to_f
    @anchor_lng = anchor_lng.to_f
    @date = parse_date(date)
    @depart_time = depart_time.to_s.presence || "8:00 AM"
    @return_time = return_time.to_s.presence || "7:00 PM"
    @interests = Array(interests).map(&:to_s).reject(&:blank?)
    @ideas = Array(ideas)
    @people = Array(people)
  end

  def call
    result = Ai::Caller.call(slug: PROMPT_SLUG, variables: prompt_vars)
    parsed = result.json
    return fallback unless parsed.is_a?(Hash)
    coerce_shape(parsed)
  rescue StandardError => e
    Rails.logger.warn("[DayPlanBuilder] #{e.class}: #{e.message}")
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
      anchor: @anchor_label,
      anchor_lat: @anchor_lat,
      anchor_lng: @anchor_lng,
      date_label: @date.strftime("%A %b %-d, %Y"),
      depart_time: @depart_time,
      return_time: @return_time,
      interests: @interests,
      ideas: @ideas.map { |i|
        {
          name: i[:name] || i["name"],
          summary: i[:summary] || i["summary"],
          interest: i[:interest] || i["interest"],
          latitude: i[:latitude] || i["latitude"],
          longitude: i[:longitude] || i["longitude"]
        }
      },
      people: @people.map { |p| { name: p[:name], age: p[:age], interests: Array(p[:interests]) } }
    }
  end

  def coerce_shape(hash)
    {
      "excitement_pitch" => hash["excitement_pitch"].to_s.strip,
      "days" => Array(hash["days"]).first(1).map.with_index do |d, i|
        {
          "label" => "day-1",
          "date" => @date.iso8601,
          "title" => d["title"].to_s.presence || "Day trip",
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
              "group_label" => a["group_label"].to_s,
              "image_query" => a["image_query"].to_s,
              "guide_script" => a["guide_script"].to_s
            }
          end
        }
      end,
      "checklist" => {
        # Day trips collapse before_trip → day-of essentials only.
        "before_trip" => Array(hash.dig("checklist", "day_of")).map do |item|
          {
            "title" => item["title"].to_s,
            "category" => item["category"].to_s.presence || "Day-of"
          }
        end,
        "day" => [],
        "activity" => []
      }
    }
  end

  def fallback
    activities = @ideas.first(4).map.with_index do |idea, i|
      time = [ @depart_time, "11:00 AM", "1:30 PM", "4:00 PM" ][i % 4]
      {
        "time_label" => time,
        "title" => idea[:name] || idea["name"],
        "location_name" => idea[:name] || idea["name"],
        "address" => "",
        "latitude" => idea[:latitude] || idea["latitude"],
        "longitude" => idea[:longitude] || idea["longitude"],
        "famous_for" => idea[:summary] || idea["summary"] || "",
        "notes" => "",
        "group_label" => "",
        "image_query" => idea[:name] || idea["name"],
        "guide_script" => ""
      }
    end

    {
      "excitement_pitch" => "",
      "days" => [ {
        "label" => "day-1",
        "date" => @date.iso8601,
        "title" => "Day trip from #{@anchor_label}",
        "theme" => "Explore",
        "summary" => "Round-trip exploration of nearby favorites.",
        "accent" => ACCENTS[0],
        "activities" => activities
      } ],
      "checklist" => {
        "before_trip" => [
          { "title" => "Full tank + tire check", "category" => "Vehicle" },
          { "title" => "Water (1L per person, more if hiking)", "category" => "Packing" },
          { "title" => "Snacks and sandwiches", "category" => "Packing" },
          { "title" => "Layered clothing for changing weather", "category" => "Packing" }
        ],
        "day" => [],
        "activity" => []
      }
    }
  end
end
