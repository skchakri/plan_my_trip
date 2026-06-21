require "test_helper"

class TripStyleEditTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "s-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "S")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    @trip = @user.owned_trips.create!(title: "T", destination: "Zion", start_date: Date.current,
                                      end_date: Date.current + 2, build_status: "ready")
  end

  test "owner can update pace, budget, preferences and transport_mode" do
    patch trip_path(@trip), params: { trip: {
      pace: "relaxed", budget: "luxury", preferences: "vegetarian, no long hikes", transport_mode: "own_car"
    } }
    @trip.reload
    assert_equal "relaxed", @trip.pace
    assert_equal "luxury", @trip.budget
    assert_equal "vegetarian, no long hikes", @trip.preferences
    assert_equal "own_car", @trip.transport_mode
  end

  test "the edit form exposes the trip-style fields" do
    get edit_trip_path(@trip)
    assert_response :success
    assert_select "select[name=?]", "trip[pace]"
    assert_select "select[name=?]", "trip[budget]"
    assert_select "select[name=?]", "trip[transport_mode]"
    assert_select "textarea[name=?]", "trip[preferences]"
  end
end
