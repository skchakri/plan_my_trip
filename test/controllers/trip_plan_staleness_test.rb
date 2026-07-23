require "test_helper"

# Editing a trip after its AI plan was built used to change only the header —
# the TripDay/Activity rows kept describing the old destination, so a trip
# retitled "San Francisco" still had a Disneyland itinerary under it. Dates now
# slide deterministically; anything else flags the plan stale and offers
# Rebuild on trips/show.
class TripPlanStalenessTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "p-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "P")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    @trip = @user.owned_trips.create!(
      title: "Anaheim — Jul 24-26",
      destination: "Anaheim, CA",
      start_date: Date.new(2026, 7, 24),
      end_date: Date.new(2026, 7, 26),
      build_status: "ready"
    )
    @days = 3.times.map do |i|
      @trip.trip_days.create!(
        title: "Day #{i + 1}", label: "day-#{i + 1}", position: i,
        date: Date.new(2026, 7, 24) + i
      )
    end
  end

  test "changing the destination marks the built plan stale" do
    patch trip_path(@trip), params: { trip: { destination: "San Francisco, CA" } }
    assert @trip.reload.plan_stale?, "destination change should flag the plan"
    assert_match(/rebuild/i, flash[:notice])
  end

  test "changing a planning lever marks the built plan stale" do
    patch trip_path(@trip), params: { trip: { pace: "relaxed" } }
    assert @trip.reload.plan_stale?
  end

  test "editing only the title leaves the plan fresh" do
    patch trip_path(@trip), params: { trip: { title: "Disney week" } }
    refute @trip.reload.plan_stale?
    assert_equal "Trip updated.", flash[:notice]
  end

  test "a trip with no built days is never flagged" do
    bare = @user.owned_trips.create!(title: "Bare", destination: "Moab", build_status: "ready")
    patch trip_path(bare), params: { trip: { destination: "Zion" } }
    refute bare.reload.plan_stale?
  end

  test "moving the start date slides every day by the same delta" do
    patch trip_path(@trip), params: {
      trip: { start_date: "2026-07-31", end_date: "2026-08-02" }
    }
    assert_equal [ Date.new(2026, 7, 31), Date.new(2026, 8, 1), Date.new(2026, 8, 2) ],
                 @trip.reload.trip_days.ordered.map(&:date)
    refute @trip.plan_stale?, "a pure date move is reconciled, not stale"
    assert_match(/7 days later/, flash[:notice])
  end

  test "extending the trip past the built days flags the plan" do
    patch trip_path(@trip), params: { trip: { end_date: "2026-07-29" } }
    assert @trip.reload.plan_stale?, "6 days of range over 3 built days is a mismatch"
  end

  test "the stale banner offers a rebuild to the owner and hides once rebuilt" do
    @trip.mark_plan_stale!
    get trip_path(@trip)
    assert_response :success
    assert_select "form[action=?]", rebuild_trip_path(@trip)
    assert_select "p", text: "This plan is out of date"

    @trip.mark_plan_fresh!
    get trip_path(@trip)
    assert_select "form[action='#{rebuild_trip_path(@trip)}']", count: 0
  end

  test "a viewer sees the warning but no rebuild button" do
    viewer = User.create!(email: "v-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "V")
    @trip.trip_memberships.create!(user: viewer, role: "member", accepted_at: Time.current)
    @trip.mark_plan_stale!

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: viewer.email, password: "password123" } }
    get trip_path(@trip)
    assert_response :success
    assert_select "p", text: "This plan is out of date"
    assert_select "form[action='#{rebuild_trip_path(@trip)}']", count: 0
  end
end
