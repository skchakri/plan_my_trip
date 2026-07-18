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

  test "dossier surfaces confirmed bookings with their notes" do
    @trip.booking_claims.create!(kind: "stays", note: "Hampton Inn Springdale, conf #ABC123")
    d = TripAgent.new(trip: @trip, user: @user, question: "where am I staying?").dossier
    assert_includes d, "Confirmed by the traveler:"
    assert_includes d, "Stays: booked"
    assert_includes d, "Hampton Inn Springdale"
    assert_includes d, "Not booked yet:"
  end

  # ── converse (trip_concierge.v2 — chat + proposed edits) ──────────────

  test "converse parses a JSON reply and sanitized proposed edits" do
    payload = {
      reply: "I can add a sunset stop to day 1 — tap Apply below.",
      proposed_edits: [
        { action: "add_activity", day_number: 1, activity_title: nil, title: "Sunset at the overlook",
          time_label: "7:30 PM", location_name: "Canyon Overlook", notes: nil, direction: nil }
      ]
    }.to_json
    TripAgent.ai_caller = FakeCaller.new(text: payload)

    ex = TripAgent.new(trip: @trip, user: @user, question: "add a sunset stop to day 1").converse

    assert_nil ex.error
    assert_equal "I can add a sunset stop to day 1 — tap Apply below.", ex.reply
    assert_equal 1, ex.edits.size
    edit = ex.edits.first
    assert_equal "add_activity", edit["action"]
    assert_equal 1, edit["day_number"]
    assert_equal "Sunset at the overlook", edit["title"]
    assert_equal "Canyon Overlook", edit["location_name"]
    refute edit.key?("direction") # blank fields dropped by sanitize_edits
  end

  test "converse keeps day-less actions (checklist / pace) without a day_number" do
    payload = {
      reply: "Slowing the pace and adding a packing item — tap Apply.",
      proposed_edits: [
        { action: "update_pace", day_number: nil, pace: "relaxed", title: nil },
        { action: "add_checklist_item", day_number: nil, title: "Pack sunscreen", category: "Health" }
      ]
    }.to_json
    TripAgent.ai_caller = FakeCaller.new(text: payload)

    ex = TripAgent.new(trip: @trip, user: @user, question: "slow it down and add sunscreen").converse

    assert_equal 2, ex.edits.size
    pace = ex.edits.find { |e| e["action"] == "update_pace" }
    assert_equal "relaxed", pace["pace"]
    refute pace.key?("day_number") # no day for a trip-level action
    check = ex.edits.find { |e| e["action"] == "add_checklist_item" }
    assert_equal "Pack sunscreen", check["title"]
    assert_equal "Health", check["category"]
  end

  test "converse calls trip_concierge.v2 with the can_edit flag" do
    fake = FakeCaller.new(text: { reply: "ok", proposed_edits: [] }.to_json)
    TripAgent.ai_caller = fake

    TripAgent.new(trip: @trip, user: @user, question: "hi").converse

    assert_equal "trip_concierge.v2", fake.calls.first[:slug]
    assert_equal true, fake.calls.first[:variables][:can_edit] # owner may edit
  end

  test "converse drops unknown actions and caps the batch" do
    edits = ([ { action: "nuke_trip", day_number: 1 } ] +
             Array.new(9) { |i| { action: "update_day_title", day_number: 1, title: "T#{i}" } })
    TripAgent.ai_caller = FakeCaller.new(text: { reply: "r", proposed_edits: edits }.to_json)

    ex = TripAgent.new(trip: @trip, user: @user, question: "rename everything").converse

    assert_equal TripAgent::MAX_EDITS, ex.edits.size # unknown dropped, rest capped
    assert(ex.edits.all? { |e| e["action"] == "update_day_title" })
  end

  test "converse falls back to plain text when the backend returns prose" do
    TripAgent.ai_caller = FakeCaller.new(text: "Just a friendly non-JSON answer.")

    ex = TripAgent.new(trip: @trip, user: @user, question: "hi").converse

    assert_equal "Just a friendly non-JSON answer.", ex.reply
    assert_empty ex.edits
  end
end
