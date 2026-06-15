require "test_helper"

class BookingClaimsOneTapTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    sign_in_as(@owner)
  end

  test "one-tap creates a handled claim with no note required" do
    assert_difference -> { @trip.booking_claims.count }, 1 do
      post trip_booking_claims_path(@trip), params: { booking_claim: { kind: "stays" } }
    end
    claim = @trip.booking_claims.find_by(kind: "stays")
    assert claim.present?
    assert_redirected_to @trip
  end

  test "trip show renders the handled summary strip and one-tap buttons" do
    get trip_path(@trip)
    assert_response :success
    assert_includes response.body, "0/4 booked"
    assert_includes response.body, "booked this"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
