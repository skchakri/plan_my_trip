require "test_helper"

# Offline: no day_plan prompt is seeded in the test DB, so DayPlanBuilder falls
# back to a skeleton; with no selected ideas that skeleton has zero activities,
# so no geocoder/seeder/image network is hit.
class BuildDayTripJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "d-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Dot")
  end

  def building_day_trip(build_args: {})
    @user.owned_trips.create!(
      title: "Day trip · Home", origin: "Home", destination: "Day trip · Home",
      start_date: Date.current, end_date: Date.current, day_trip: true,
      anchor_label: "Home", anchor_lat: 40.76, anchor_lng: -111.89, max_radius_km: 80,
      build_status: "building", build_args: build_args
    )
  end

  test "assembles a building day trip into a ready one-day plan" do
    trip = building_day_trip
    BuildDayTripJob.perform_now(trip.id)
    trip.reload
    assert_equal "ready", trip.build_status
    assert_equal 1, trip.trip_days.size, "exactly one day"
    assert trip.checklist_items.any?, "day-of essentials checklist is built"
  end

  test "enqueues narration backfill after a successful build" do
    trip = building_day_trip
    assert_enqueued_with(job: BackfillTripNarrationsJob, args: [ trip.id ]) do
      BuildDayTripJob.perform_now(trip.id)
    end
  end

  test "ignores trips that are not building" do
    trip = building_day_trip
    trip.update_column(:build_status, "ready")
    BuildDayTripJob.perform_now(trip.id)
    assert_equal 0, trip.reload.trip_days.size
  end

  test "missing trip is a no-op" do
    assert_nothing_raised { BuildDayTripJob.perform_now(SecureRandom.uuid) }
  end
end
