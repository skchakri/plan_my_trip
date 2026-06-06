require "test_helper"

class TripStructureBuilderPrefsTest < ActiveSupport::TestCase
  test "prompt vars carry pace, budget, and preferences through" do
    builder = TripStructureBuilder.new(
      destination: "Moab, UT", start_date: Date.current, end_date: Date.current + 2,
      pace: "relaxed", budget: "luxury", preferences: "vegetarian; no long hikes"
    )
    vars = builder.send(:prompt_vars)
    assert_equal "relaxed", vars[:pace]
    assert_equal "luxury", vars[:budget]
    assert_equal "vegetarian; no long hikes", vars[:preferences]
  end

  test "blank preferences normalize to nil" do
    builder = TripStructureBuilder.new(
      destination: "Moab", start_date: Date.current, end_date: Date.current + 1,
      pace: "", budget: nil, preferences: "  "
    )
    vars = builder.send(:prompt_vars)
    assert_nil vars[:pace]
    assert_nil vars[:budget]
    assert_nil vars[:preferences]
  end
end
