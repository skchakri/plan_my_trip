require "test_helper"

# Render-level checks for live collaborative editing (board 1257aed1): the
# morph page-refresh meta tags, the trips/show stream subscription, the
# data-turbo-permanent guards, and the absence of any subscription on the
# public share view (no broadcast leak to anonymous viewers).
class TripsLiveMorphTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owner")
    @member = User.create!(email: "member-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Mel")
    @trip = @owner.owned_trips.create!(
      title: "Vegas", destination: "Las Vegas, NV",
      start_date: Date.current, end_date: Date.current + 3
    )
    # Second member so the presence widget renders (>1 member).
    @trip.trip_memberships.create!(user: @member, role: "member", accepted_at: Time.current)
  end

  test "layout emits Turbo 8 morph page-refresh meta tags" do
    sign_in_as(@owner)
    get trip_path(@trip)
    assert_response :success
    assert_match %r{<meta name="turbo-refresh-method" content="morph">}, response.body
    assert_match %r{<meta name="turbo-refresh-scroll" content="preserve">}, response.body
  end

  test "trips/show subscribes to the trip stream and guards live inputs" do
    sign_in_as(@owner)
    get trip_path(@trip)
    assert_response :success
    assert_includes response.body, "turbo-cable-stream-source",
      "show page should subscribe via turbo_stream_from @trip"
    # Presence widget + rename input survive a morph.
    assert_includes response.body, "id=\"trip-presence-#{@trip.id}\""
    assert_match %r{id="trip-presence-#{@trip.id}"[^>]*data-turbo-permanent}, response.body
    assert_match %r{id="custom-title"[^>]*data-turbo-permanent|data-turbo-permanent[^>]*id="custom-title"}, response.body
  end

  test "public share view never subscribes to the trip stream" do
    @trip.enable_share_link!
    get public_trip_path(@trip.share_token)
    assert_response :success
    assert_not_includes response.body, "turbo-cable-stream-source",
      "public read-only view must not subscribe — broadcasts must not reach anonymous viewers"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
