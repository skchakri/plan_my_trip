require "test_helper"

class TripWalletTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "w-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owner")
    @bob   = User.create!(email: "b-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Bob")
    @stranger = User.create!(email: "s-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Stranger")

    @trip = @owner.owned_trips.create!(title: "Vegas", destination: "Las Vegas, NV",
                                       start_date: Date.current, end_date: Date.current + 2)
    @trip.trip_memberships.create!(user: @bob, role: "member", accepted_at: Time.current)
    day = @trip.trip_days.create!(label: "day-1", title: "Drive", accent: "blue", position: 1, date: @trip.start_date)
    day.activities.create!(title: "Bellagio Fountains", time_label: "20:00", position: 1,
                           location_name: "Bellagio", address: "3600 Las Vegas Blvd",
                           latitude: 36.11, longitude: -115.17)
    @trip.trails.create!(name: "Red Rocks Loop", alltrails_url: "https://www.alltrails.com/trail/x", position: 1)
  end

  test "owner can fetch wallet and the page lists addresses + coords" do
    sign_in_as(@owner)
    get wallet_trip_path(@trip)
    assert_response :success
    assert_includes response.body, "Vegas"
    assert_includes response.body, "Bellagio Fountains"
    assert_includes response.body, "3600 Las Vegas Blvd"
    assert_includes response.body, "36.11"
    assert_includes response.body, "Red Rocks Loop"
    # Wallet layout — no app chrome
    refute_includes response.body, "Open my trips"
  end

  test "trip member can fetch wallet" do
    sign_in_as(@bob)
    get wallet_trip_path(@trip)
    assert_response :success
  end

  test "non-member is rejected" do
    sign_in_as(@stranger)
    get wallet_trip_path(@trip)
    assert_response :redirect
  end

  test "unauthenticated request redirects to sign-in" do
    get wallet_trip_path(@trip)
    assert_response :redirect
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
