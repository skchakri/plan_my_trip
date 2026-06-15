require "test_helper"

class PublicTripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@test.example",
      password: "password123",
      name: "Owner"
    )
    @trip = @owner.owned_trips.create!(
      title: "Vegas",
      destination: "Las Vegas, NV",
      start_date: Date.current,
      end_date: Date.current + 3
    )
  end

  test "GET /s/:token renders the trip when link is active" do
    @trip.enable_share_link!
    get public_trip_path(@trip.share_token)
    assert_response :success
    assert_includes response.body, "Vegas"
    # No auth nav should leak through the public layout.
    assert_includes response.body, "noindex"
  end

  test "GET /s/:token returns 410 Gone after revocation" do
    @trip.enable_share_link!
    token = @trip.share_token
    @trip.disable_share_link!

    get public_trip_path(token)
    assert_response :gone
  end

  test "GET /s/:token returns 410 Gone for an unknown token" do
    get public_trip_path("not-a-real-token-aaaaaaaaaaaaaaaaaaaaa")
    assert_response :gone
  end

  test "GET /s/:token returns 410 Gone for a discarded trip" do
    @trip.enable_share_link!
    token = @trip.share_token
    @trip.discard

    get public_trip_path(token)
    assert_response :gone
  end

  test "enable requires the owner" do
    other = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@test.example",
      password: "password123",
      name: "Stranger"
    )
    sign_in_as(other)
    post enable_public_share_trip_path(@trip)
    # Pundit denies → flash alert + redirect to referrer (root).
    assert_response :redirect
    assert @trip.reload.share_token.blank?
  end

  test "owner can enable, rotate, and disable" do
    sign_in_as(@owner)

    post enable_public_share_trip_path(@trip)
    assert_response :redirect
    @trip.reload
    assert @trip.share_link_active?
    first_token = @trip.share_token

    post rotate_public_share_trip_path(@trip)
    @trip.reload
    assert @trip.share_link_active?
    refute_equal first_token, @trip.share_token, "rotate should mint a new token"

    delete disable_public_share_trip_path(@trip)
    @trip.reload
    refute @trip.share_link_active?
    assert @trip.share_token.present?, "token is preserved across disable for re-enable"
  end

  test "signed-in visitor can save a copy of a shared trip to their own trips" do
    @trip.enable_share_link!
    @trip.trip_days.create!(label: "Day 1", title: "Arrive", position: 0, accent: "gold")
    visitor = User.create!(email: "v-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Val")
    sign_in_as(visitor)

    assert_difference -> { visitor.owned_trips.count }, 1 do
      post save_public_trip_path(@trip.share_token)
    end
    clone = visitor.owned_trips.order(:created_at).last
    assert_equal "Vegas", clone.title
    assert_redirected_to clone
    assert_equal 1, clone.trip_days.count
  end

  test "saving requires sign-in" do
    @trip.enable_share_link!
    post save_public_trip_path(@trip.share_token)
    assert_response :redirect # bounced to sign in
  end

  test "saving a revoked link is gone" do
    @trip.enable_share_link!
    token = @trip.share_token
    @trip.disable_share_link!
    sign_in_as(@owner)
    post save_public_trip_path(token)
    assert_response :gone
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
