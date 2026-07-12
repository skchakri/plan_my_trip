require "test_helper"

class TripsConciergeTest < ActionDispatch::IntegrationTest
  # Fake AI backend injected via TripAgent.ai_caller (the suite avoids mocks).
  class FakeCaller
    def initialize(text:)
      @text = text
    end

    def call(**)
      Ai::Result.new(text: @text)
    end
  end

  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @stranger = User.create!(email: "x-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Xan")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
  end

  teardown { TripAgent.ai_caller = nil }

  test "show page renders the concierge panel" do
    sign_in_as(@owner)
    get trip_path(@trip)
    assert_response :success
    assert_includes response.body, "Trip concierge"
    assert_includes response.body, concierge_trip_path(@trip)
  end

  test "asking a question streams the answer back into the log" do
    TripAgent.ai_caller = FakeCaller.new(text: "Day 1 is a relaxed canyon day.")
    sign_in_as(@owner)

    post concierge_trip_path(@trip), params: { question: "What's day 1?" }, as: :turbo_stream
    assert_response :success
    assert_includes response.body, "concierge-log"                  # appended to the log
    assert_includes response.body, "What&#39;s day 1?"              # the question bubble (HTML-escaped)
    assert_includes response.body, "Day 1 is a relaxed canyon day." # the answer
  end

  test "a blank question is rejected" do
    sign_in_as(@owner)
    post concierge_trip_path(@trip), params: { question: "   " }, as: :turbo_stream
    assert_response :bad_request
  end

  test "a stranger with no access is denied before any AI call" do
    sign_in_as(@stranger)
    post concierge_trip_path(@trip), params: { question: "secrets?" }, as: :turbo_stream
    assert_response :redirect # Pundit denial → redirected away
  end

  test "an editor sees Apply cards for proposed edits" do
    TripAgent.ai_caller = FakeCaller.new(text: {
      reply: "I can rename day 1.",
      proposed_edits: [ { action: "update_day_title", day_number: 1, activity_title: nil,
                          title: "Canyon day", time_label: nil, location_name: nil, notes: nil, direction: nil } ]
    }.to_json)
    sign_in_as(@owner)

    post concierge_trip_path(@trip), params: { question: "rename day 1 to Canyon day" }, as: :turbo_stream
    assert_response :success
    assert_includes response.body, "Proposed edit"
    assert_includes response.body, concierge_edit_trip_path(@trip)
    assert_includes response.body, "Rename day 1" # the card's human label
  end

  test "a viewer gets the reply but no Apply cards" do
    @trip.trip_memberships.create!(user: @stranger, role: "member") # view-only
    TripAgent.ai_caller = FakeCaller.new(text: {
      reply: "Here's an idea.",
      proposed_edits: [ { action: "update_day_title", day_number: 1, activity_title: nil,
                          title: "X", time_label: nil, location_name: nil, notes: nil, direction: nil } ]
    }.to_json)
    sign_in_as(@stranger)

    post concierge_trip_path(@trip), params: { question: "rename day 1" }, as: :turbo_stream
    assert_response :success
    assert_includes response.body, "Here&#39;s an idea."
    refute_includes response.body, "Proposed edit" # editor-only affordance
  end

  test "concierge_edit applies an edit for an editor and confirms in place" do
    day = @trip.trip_days.create!(label: "day-1", title: "Old", accent: "blue", position: 0)
    sign_in_as(@owner)

    post concierge_edit_trip_path(@trip), params: {
      edit_action: "update_day_title", day_number: 1, title: "Canyon day", card_id: "edit-abc"
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "edit-abc" # replaced the same card
    assert_equal "Canyon day", day.reload.title
  end

  test "concierge_edit is denied for a view-only member" do
    @trip.trip_memberships.create!(user: @stranger, role: "member")
    @trip.trip_days.create!(label: "day-1", title: "Old", accent: "blue", position: 0)
    sign_in_as(@stranger)

    post concierge_edit_trip_path(@trip), params: {
      edit_action: "update_day_title", day_number: 1, title: "Hacked"
    }, as: :turbo_stream
    assert_response :redirect # Pundit :update? denial
    assert_equal "Old", @trip.trip_days.first.reload.title
  end

  test "concierge_edit turns a bad edit into a friendly error card" do
    @trip.trip_days.create!(label: "day-1", title: "Old", accent: "blue", position: 0)
    sign_in_as(@owner)

    post concierge_edit_trip_path(@trip), params: {
      edit_action: "add_activity", day_number: 1, title: "", card_id: "edit-x"
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "title is required" # TripEditor's friendly failure
  end

  test "concierge_edit rejects an action outside the allowlist" do
    sign_in_as(@owner)
    post concierge_edit_trip_path(@trip), params: { edit_action: "delete_trip", day_number: 1 }, as: :turbo_stream
    assert_response :bad_request
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
