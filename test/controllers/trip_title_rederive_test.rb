require "test_helper"

# A trip's title auto-generates from destination + dates. If the user never
# renamed it, editing the destination must re-derive the title — otherwise a
# trip moved from San Francisco to Los Angeles keeps reading "San Francisco".
# A title the user actually typed is left alone.
class TripTitleRederiveTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "tt-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "TT")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  def auto_titled_trip(dest: "San Francisco", s: Date.new(2026, 7, 24), e: Date.new(2026, 7, 29))
    @user.owned_trips.create!(
      title: Trip.derive_title(destination: dest, start_date: s, end_date: e),
      destination: dest, start_date: s, end_date: e, build_status: "ready"
    )
  end

  test "changing the destination re-derives an auto-generated title" do
    trip = auto_titled_trip
    assert_equal "San Francisco — Jul 24-29, 2026", trip.title

    patch trip_path(trip), params: { trip: { title: trip.title, destination: "Los Angeles" } }

    assert_equal "Los Angeles — Jul 24-29, 2026", trip.reload.title
  end

  test "a user-customized title is preserved when the destination changes" do
    trip = auto_titled_trip
    trip.update!(title: "Squad trip 2026")

    patch trip_path(trip), params: { trip: { title: "Squad trip 2026", destination: "Los Angeles" } }

    assert_equal "Squad trip 2026", trip.reload.title
    assert_equal "Los Angeles", trip.destination
  end

  test "editing the title itself is honored" do
    trip = auto_titled_trip
    patch trip_path(trip), params: { trip: { title: "Golden Gate week", destination: trip.destination } }
    assert_equal "Golden Gate week", trip.reload.title
  end

  test "moving the dates re-derives an auto-generated title" do
    trip = auto_titled_trip
    patch trip_path(trip), params: {
      trip: { title: trip.title, start_date: "2026-08-01", end_date: "2026-08-05" }
    }
    assert_equal "San Francisco — Aug 1-5, 2026", trip.reload.title
  end
end
