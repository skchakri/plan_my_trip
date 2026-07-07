require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    @failed = @trip.reservations.create!(kind: "other", status: "failed", raw_email: "Confirmation #ABC123")
    sign_in_as(@owner)
  end

  test "retry re-enqueues the parse job and flips the reservation back to parsing" do
    assert_enqueued_with(job: ParseReservationJob) do
      post retry_trip_reservation_path(@trip, @failed)
    end
    assert_redirected_to @trip
    assert_equal "parsing", @failed.reload.status
  end

  test "retry is a no-op when there is no stored raw email" do
    @failed.update!(raw_email: nil)
    assert_no_enqueued_jobs(only: ParseReservationJob) do
      post retry_trip_reservation_path(@trip, @failed)
    end
    assert_equal "failed", @failed.reload.status
  end

  test "retry only acts on failed reservations" do
    parsed = @trip.reservations.create!(kind: "stay", status: "parsed", raw_email: "x")
    assert_no_enqueued_jobs(only: ParseReservationJob) do
      post retry_trip_reservation_path(@trip, parsed)
    end
    assert_equal "parsed", parsed.reload.status
  end

  test "a plain member cannot retry another user's reservation" do
    member = User.create!(email: "member-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Milo")
    @trip.trip_memberships.create!(user: member, role: "member", accepted_at: Time.current)
    sign_in_as(member)
    assert_no_enqueued_jobs(only: ParseReservationJob) do
      post retry_trip_reservation_path(@trip, @failed)
    end
    assert_equal "failed", @failed.reload.status
  end

  private

  def sign_in_as(user)
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
