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

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
