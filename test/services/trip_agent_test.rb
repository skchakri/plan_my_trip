require "test_helper"

class TripAgentTest < ActiveSupport::TestCase
  # No-mock test seam (matches the suite): a fake AI backend that records the
  # call and returns a canned Ai::Result instead of hitting Anthropic.
  class FakeCaller
    attr_reader :calls

    def initialize(text: "ok")
      @text = text
      @calls = []
    end

    def call(**kwargs)
      @calls << kwargs
      Ai::Result.new(text: @text)
    end
  end

  setup do
    @user = User.create!(email: "a-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Ada")
    @trip = @user.owned_trips.create!(
      title: "Zion adventure", destination: "Springdale, UT", origin: "SLC",
      start_date: Date.new(2026, 5, 15), end_date: Date.new(2026, 5, 17),
      pace: "balanced", budget: "moderate"
    )
    day = @trip.trip_days.create!(label: "day-1", title: "Canyon day", accent: "blue", position: 0, date: @trip.start_date)
    day.activities.create!(title: "Angels Landing", time_label: "08:00", position: 0,
                           location_name: "Zion NP", address: "Springdale", latitude: 37.27, longitude: -112.95)
    @trip.people.create!(name: "Sam", age: 9, interests: [ "hiking" ], position: 0)
  end

  teardown { TripAgent.ai_caller = nil }

  test "dossier grounds the agent in the trip's real facts" do
    d = TripAgent.new(trip: @trip, user: @user, question: "x").dossier
    assert_includes d, "Zion adventure"
    assert_includes d, "Springdale, UT"
    assert_includes d, "Pace: balanced"
    assert_includes d, "Angels Landing"   # itinerary
    assert_includes d, "Sam"              # traveler roster
    assert_includes d, "hiking"
  end

  test "answer calls trip_concierge.v1 with the dossier and returns the text" do
    fake = FakeCaller.new(text: "Day 1 is a full canyon day.")
    TripAgent.ai_caller = fake

    result = TripAgent.new(trip: @trip, user: @user, question: "How long is day 1?").answer

    assert_equal "Day 1 is a full canyon day.", result.text
    assert_equal 1, fake.calls.size
    assert_equal "trip_concierge.v1", fake.calls.first[:slug]
    assert_includes fake.calls.first[:variables][:dossier], "Angels Landing"
    assert_equal "How long is day 1?", fake.calls.first[:variables][:question]
  end

  test "a blank question short-circuits and never calls the model" do
    fake = FakeCaller.new
    TripAgent.ai_caller = fake

    result = TripAgent.new(trip: @trip, user: @user, question: "   ").answer

    assert_not result.success?
    assert_empty fake.calls
  end

  test "dossier degrades gracefully for an unbuilt trip" do
    bare = @user.owned_trips.create!(title: "Empty", destination: "TBD",
                                     start_date: Date.current, end_date: Date.current + 1)
    d = TripAgent.new(trip: bare, user: @user, question: "x").dossier
    assert_includes d, "Empty"
    assert_includes d, "ITINERARY: not built yet."
  end
end
