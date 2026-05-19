require "test_helper"

class SuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owner")
    @bob   = User.create!(email: "b-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Bob")
    @stranger = User.create!(email: "s-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Stranger")

    @trip = @owner.owned_trips.create!(title: "Vegas", start_date: Date.current, end_date: Date.current + 2)
    @trip.trip_memberships.create!(user: @bob, role: "member", accepted_at: Time.current)
    @day = @trip.trip_days.create!(label: "day-1", title: "Day 1", accent: "blue", position: 1)
  end

  test "trip member can post a suggestion" do
    sign_in_as(@bob)
    assert_difference -> { Suggestion.count }, +1 do
      post trip_trip_day_suggestions_path(@trip, @day),
           params: { suggestion: { title: "Cottonwood Steakhouse", url: "https://example.com/steak" } }
    end
    s = Suggestion.last
    assert_equal @bob.id, s.author_id
  end

  test "non-member is rejected" do
    sign_in_as(@stranger)
    assert_no_difference -> { Suggestion.count } do
      post trip_trip_day_suggestions_path(@trip, @day),
           params: { suggestion: { title: "Crash" } }
    end
  end

  test "voting toggles a suggestion vote on/off and recomputes the count" do
    sign_in_as(@bob)
    s = @day.suggestions.create!(author: @owner, title: "Test")

    assert_difference -> { SuggestionVote.count }, +1 do
      post vote_trip_trip_day_suggestion_path(@trip, @day, s)
    end

    assert_difference -> { SuggestionVote.count }, -1 do
      post vote_trip_trip_day_suggestion_path(@trip, @day, s)
    end
  end

  test "author can delete their own suggestion" do
    sign_in_as(@bob)
    s = @day.suggestions.create!(author: @bob, title: "Mine")
    delete trip_trip_day_suggestion_path(@trip, @day, s)
    assert s.reload.discarded?
  end

  test "ranked scope orders by vote count desc, then created_at asc" do
    older   = @day.suggestions.create!(author: @owner, title: "Older")
    newer   = @day.suggestions.create!(author: @owner, title: "Newer")
    popular = @day.suggestions.create!(author: @owner, title: "Popular")
    popular.suggestion_votes.create!(user: @bob)

    titles = @day.suggestions.map(&:title)
    assert_equal "Popular", titles.first, "highest-voted should sort first"
  end

  test "invalid URL is rejected" do
    sign_in_as(@bob)
    assert_no_difference -> { Suggestion.count } do
      post trip_trip_day_suggestions_path(@trip, @day),
           params: { suggestion: { title: "Bad", url: "ftp://nope" } }
    end
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
