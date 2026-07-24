require "test_helper"

# Every edit path funnels through Trips::Resync so the header (auto-title) and
# the rendered "final plan" (Trip#body markdown) never drift from the edited
# structured rows — the trip edit form, the structured day/activity editor, and
# the concierge all stay in sync.
class TripResyncTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "rs-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "RS")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    @trip = @user.owned_trips.create!(
      title: Trip.derive_title(destination: "Anaheim", start_date: Date.new(2026, 7, 24), end_date: Date.new(2026, 7, 26)),
      destination: "Anaheim", start_date: Date.new(2026, 7, 24), end_date: Date.new(2026, 7, 26),
      build_status: "ready"
    )
    @day = @trip.trip_days.create!(title: "Day 1", label: "day-1", position: 0, date: Date.new(2026, 7, 24))
    @day.activities.create!(title: "Old Stop", position: 0, time_label: "9:00 AM")
    Trips::BodySync.call(@trip) # seed the derived body
  end

  test "editing a day title rewrites the final-plan body" do
    patch trip_trip_day_path(@trip, @day), params: { trip_day: { title: "Disneyland Day" } }
    assert_includes @trip.reload.body, "Disneyland Day"
  end

  test "editing an activity rewrites the final-plan body" do
    activity = @day.activities.first
    patch trip_activity_path(@trip, activity), params: { activity: { title: "Rope Drop Space Mountain" } }
    assert_includes @trip.reload.body, "Rope Drop Space Mountain"
  end

  test "changing the destination re-derives the auto-title and the body overview" do
    patch trip_path(@trip), params: { trip: { destination: "Los Angeles" } }
    @trip.reload
    assert_equal "Los Angeles — Jul 24-26, 2026", @trip.title
    assert_includes @trip.body, "trip to **Los Angeles**"
  end

  test "a hand-edited body is not clobbered by resync on the same submit" do
    patch trip_path(@trip), params: { trip: { destination: "Los Angeles", body: "# My own plan" } }
    assert_equal "# My own plan", @trip.reload.body
  end

  test "concierge activity edit rewrites the final-plan body" do
    editor = TripEditor.new(trip: @trip, user: @user)
    editor.add_activity(day_number: 1, title: "Sunset at the Pier", time_label: "7:00 PM")
    assert_includes @trip.reload.body, "Sunset at the Pier"
  end
end
