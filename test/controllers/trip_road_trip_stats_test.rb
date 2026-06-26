require "test_helper"

class TripRoadTripStatsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "rts-o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owen")
    @other = User.create!(email: "rts-x-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Xavier")
    @trip = @owner.owned_trips.create!(
      title: "Road loop", transport_mode: "own_car", origin: "",
      start_date: Date.current, end_date: Date.current + 2
    )
  end

  # No geocoded stops → RoadTripEstimator returns nil with no network call, so
  # the endpoint renders the friendly empty state. (The full math path is
  # covered by RoadTripEstimatorTest, which stubs OSRM.)
  test "own-car trip renders the road-trip stats frame (empty state without stops)" do
    sign_in_as(@owner)
    get road_trip_stats_trip_path(@trip)
    assert_response :success
    assert_includes response.body, "road-trip-stats"
    assert_includes response.body, "Road trip stats"
    assert_includes response.body, "Add stops with locations"
  end

  test "detail variant renders the per-leg frame id" do
    sign_in_as(@owner)
    get road_trip_stats_trip_path(@trip, detail: 1)
    assert_response :success
    assert_includes response.body, "road-trip-legs"
  end

  test "the show page embeds the lazy road-trip-stats frame for own-car trips" do
    sign_in_as(@owner)
    get trip_path(@trip)
    assert_response :success
    assert_includes response.body, road_trip_stats_trip_path(@trip)
  end

  test "the show page omits the frame when the trip is not own-car" do
    @trip.update!(transport_mode: "flying")
    sign_in_as(@owner)
    get trip_path(@trip)
    assert_response :success
    assert_not_includes response.body, road_trip_stats_trip_path(@trip)
  end

  test "a user without access is redirected (Pundit)" do
    sign_in_as(@other)
    get road_trip_stats_trip_path(@trip)
    assert_response :redirect
  end

  test "a discarded trip 404s" do
    @trip.discard
    sign_in_as(@owner)
    get road_trip_stats_trip_path(@trip)
    assert_response :not_found
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
