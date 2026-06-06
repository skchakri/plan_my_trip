require "test_helper"

class MarkdownItineraryTest < ActiveSupport::TestCase
  STRUCTURE = {
    "excitement_pitch" => "Big fun ahead.",
    "days" => [
      {
        "title" => "Arrival", "date" => "2026-07-01", "summary" => "Drive in and settle.",
        "activities" => [
          { "time_label" => "9:00 AM", "title" => "Zion Narrows", "famous_for" => "slot-canyon river hike" },
          { "title" => "Dinner", "notes" => "tacos downtown" }
        ]
      }
    ]
  }.freeze

  test "derives an overview, day sections, and activity lines from the structure" do
    md = MarkdownItinerary.from_structure(STRUCTURE, destination: "Springdale", people: [ { name: "Sam" } ])
    assert_includes md, "## Overview"
    assert_includes md, "Springdale"
    assert_includes md, "for Sam"
    assert_includes md, "Big fun ahead."
    assert_includes md, "## Arrival — Wednesday, Jul 1"
    assert_includes md, "Drive in and settle."
    assert_includes md, "9:00 AM · **Zion Narrows** — slot-canyon river hike"
    assert_includes md, "**Dinner** — tacos downtown"
  end

  test "handles an empty structure without raising" do
    md = MarkdownItinerary.from_structure({}, destination: "Nowhere")
    assert_includes md, "## Overview"
    assert_includes md, "0-day trip"
  end
end
