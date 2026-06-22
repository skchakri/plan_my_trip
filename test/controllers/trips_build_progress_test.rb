require "test_helper"

class TripsBuildProgressTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "bp-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "BP")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "the building page renders live step progress for a multi-day trip" do
    t = @user.owned_trips.create!(title: "Zion", destination: "Zion", start_date: Date.current,
                                  end_date: Date.current + 2, build_status: "building")
    t.update_columns(build_step: 2)
    get trip_path(t)
    assert_response :success
    assert_select "#trip-build-progress"
    assert_includes response.body, "Researching" # step 0 (done at build_step 2)
    assert_includes response.body, "Finding drive-by landmarks for the road" # step 3 (pending)
  end

  test "the building page shows day-trip-specific step labels" do
    t = @user.owned_trips.create!(title: "Day out", destination: "Day trip · Home",
                                  start_date: Date.current, end_date: Date.current,
                                  build_status: "building", day_trip: true,
                                  anchor_label: "Home", anchor_lat: 40.0, anchor_lng: -111.0, max_radius_km: 80)
    t.update_columns(build_step: 1)
    get trip_path(t)
    assert_response :success
    assert_includes response.body, "Routing your stops"
  end

  test "build_step defaults to 0 for a fresh shell" do
    t = @user.owned_trips.create!(title: "X", destination: "X", start_date: Date.current,
                                  end_date: Date.current + 1, build_status: "building")
    assert_equal 0, t.build_step
  end
end
