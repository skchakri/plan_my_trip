require "test_helper"

class TripsArchiveTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @other = User.create!(email: "other-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Otto")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
  end

  test "show renders the restructured hero header with a full-width title and More menu" do
    sign_in_as(@owner)
    get trip_path(@trip)
    assert_response :success
    assert_includes response.body, "Zion loop"
    assert_includes response.body, "Wallet (print sheet)" # secondary actions folded into More menu
    assert_includes response.body, wallet_trip_path(@trip)
  end

  test "index renders the dashboard with the new card layout" do
    sign_in_as(@owner)
    get trips_path
    assert_response :success
    assert_includes response.body, "Zion loop"
    assert_includes response.body, "Trip actions" # kebab menu aria-label
  end

  test "owner archives a trip (soft-delete), hiding it from the dashboard" do
    sign_in_as(@owner)
    patch archive_trip_path(@trip)
    assert_redirected_to trips_path
    assert @trip.reload.discarded?

    get trips_path
    assert_not_includes response.body, "Zion loop"
  end

  test "archived view lists discarded trips and renders restore/delete actions" do
    @trip.discard
    sign_in_as(@owner)
    get trips_path(archived: 1)
    assert_response :success
    assert_includes response.body, "Zion loop"
    assert_includes response.body, restore_trip_path(@trip)
    assert_includes response.body, destroy_permanently_trip_path(@trip)
  end

  test "owner restores an archived trip" do
    @trip.discard
    sign_in_as(@owner)
    patch restore_trip_path(@trip)
    assert_redirected_to trips_path(archived: 1)
    assert_not @trip.reload.discarded?
  end

  test "owner permanently deletes an archived trip" do
    @trip.discard
    sign_in_as(@owner)
    assert_difference -> { Trip.unscoped.count }, -1 do
      delete destroy_permanently_trip_path(@trip)
    end
    assert_redirected_to trips_path(archived: 1)
    assert_nil Trip.find_by(id: @trip.id)
  end

  test "a member archiving a shared trip just leaves it — the trip is untouched" do
    @trip.trip_memberships.create!(user: @other, role: "member", accepted_at: Time.current)
    sign_in_as(@other)

    patch archive_trip_path(@trip)
    assert_redirected_to trips_path
    assert_not @trip.reload.discarded?, "shared trip must not be discarded by a member"
    assert_not @trip.shared_with?(@other), "member's access should be removed"
  end

  test "a non-owner cannot restore or permanently delete" do
    @trip.discard
    sign_in_as(@other)

    patch restore_trip_path(@trip)
    assert_response :not_found
    delete destroy_permanently_trip_path(@trip)
    assert_response :not_found

    assert @trip.reload.discarded?, "trip must stay archived"
    assert Trip.find_by(id: @trip.id).present?, "trip must not be deleted"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
