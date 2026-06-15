require "test_helper"

class TripEditorRoleTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @editor = User.create!(email: "editor-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Edie")
    @viewer = User.create!(email: "viewer-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Vera")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    @trip.trip_memberships.create!(user: @editor, role: "editor", accepted_at: Time.current)
    @trip.trip_memberships.create!(user: @viewer, role: "member", accepted_at: Time.current)
  end

  test "owner can edit" do
    assert @trip.editable_by?(@owner)
    sign_in_as(@owner)
    get edit_trip_path(@trip)
    assert_response :success
  end

  test "editor can reach the edit page and update the trip" do
    assert @trip.editable_by?(@editor)
    sign_in_as(@editor)
    get edit_trip_path(@trip)
    assert_response :success

    patch trip_path(@trip), params: { trip: { destination: "Springdale, UT" } }
    assert_response :redirect
    assert_equal "Springdale, UT", @trip.reload.destination
  end

  test "plain member cannot edit" do
    refute @trip.editable_by?(@viewer)
    sign_in_as(@viewer)
    get edit_trip_path(@trip)
    assert_response :redirect # Pundit NotAuthorized -> redirect
  end

  test "owner can promote a member to editor and demote back" do
    sign_in_as(@owner)
    membership = @trip.trip_memberships.find_by(user: @viewer)

    patch trip_share_path(@trip, membership), params: { role: "editor" }
    assert_equal "editor", membership.reload.role

    patch trip_share_path(@trip, membership), params: { role: "member" }
    assert_equal "member", membership.reload.role
  end

  test "editor cannot manage roles" do
    sign_in_as(@editor)
    membership = @trip.trip_memberships.find_by(user: @viewer)
    patch trip_share_path(@trip, membership), params: { role: "editor" }
    assert_response :redirect
    assert_equal "member", membership.reload.role
  end

  test "owner role cannot be changed" do
    sign_in_as(@owner)
    owner_membership = @trip.trip_memberships.find_by(user: @owner)
    patch trip_share_path(@trip, owner_membership), params: { role: "member" }
    assert_equal "owner", owner_membership.reload.role
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
