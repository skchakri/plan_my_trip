require "test_helper"

class TripsPrintableTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "p-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "P")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  def trip(status: "ready")
    @user.owned_trips.create!(title: "Zion run", destination: "Zion", start_date: Date.current,
                              end_date: Date.current + 1, build_status: status)
  end

  test "renders a printable itinerary in the print layout for a ready trip" do
    get printable_trip_path(trip)
    assert_response :success
    assert_includes response.body, "Zion run"
    assert_includes response.body, "Save as PDF" # provided by the shared wallet/print layout
  end

  test "redirects to the trip while it is still building" do
    t = trip(status: "building")
    get printable_trip_path(t)
    assert_redirected_to trip_path(t)
  end
end
