require "test_helper"

# Covers the async split: /day_trips/suggestions renders a shell with a lazy
# turbo-frame and does NOT run NearbyIdeas; /day_trips/suggestions_results is
# the frame body that runs the research. With no seeded prompt / catalog the
# research degrades to an empty list (NearbyIdeas rescues to []), so these
# stay offline and deterministic.
class DayTripsSuggestionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "d-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Dee")
  end

  ANCHOR = { anchor_label: "Salt Lake City", anchor_lat: 40.7608, anchor_lng: -111.8910, radius_km: 80 }.freeze

  test "suggestions shell renders instantly with a lazy results frame and no inline cards" do
    sign_in_as(@user)
    get day_trip_suggestions_path(ANCHOR)
    assert_response :success
    # The frame is present and points at the results endpoint…
    assert_includes response.body, "/day_trips/suggestions_results"
    assert_includes response.body, %(id="nearby-ideas")
    # …and shows the loading skeleton, not a "no ideas" verdict yet.
    assert_includes response.body, "Scouting"
  end

  test "results frame renders the nearby-ideas turbo-frame body" do
    sign_in_as(@user)
    get day_trip_suggestions_results_path(ANCHOR)
    assert_response :success
    assert_includes response.body, %(id="nearby-ideas")
    # Offline (no prompt/catalog) → empty-state copy, rendered without error.
    assert_includes response.body, "No ideas found yet"
  end

  test "missing anchor on the results frame redirects to the new form" do
    sign_in_as(@user)
    get day_trip_suggestions_results_path(anchor_label: "Nowhere")
    assert_redirected_to day_trips_new_path
  end

  test "results frame requires authentication" do
    get day_trip_suggestions_results_path(ANCHOR)
    assert_response :redirect
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
