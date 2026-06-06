require "test_helper"

# Exercises the async assembler end-to-end OFFLINE: with no seeded AI prompt the
# builders fall back to deterministic skeletons, and with no highlights the
# fallback days carry no activities — so no geocoder/seeder/image network is hit.
class BuildTripJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "b-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Bea")
  end

  def building_trip
    @user.owned_trips.create!(
      title: "Test trip", destination: "Testville", origin: "Home",
      start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 3),
      build_status: "building"
    )
  end

  test "assembles a building trip into a ready plan with days, checklist, and body" do
    trip = building_trip
    BuildTripJob.perform_now(trip.id)
    trip.reload
    assert_equal "ready", trip.build_status
    assert_nil trip.build_error
    assert_equal 3, trip.trip_days.size, "one day per date in range"
    assert trip.checklist_items.any?, "fallback before-trip checklist is built"
    assert trip.body.present?, "markdown body is derived from the structure"
    assert_includes trip.body, "Testville"
  end

  test "enqueues narration backfill after a successful build" do
    trip = building_trip
    assert_enqueued_with(job: BackfillTripNarrationsJob, args: [ trip.id ]) do
      BuildTripJob.perform_now(trip.id)
    end
  end

  test "a missing trip id is a no-op (no raise)" do
    assert_nothing_raised { BuildTripJob.perform_now(SecureRandom.uuid) }
  end

  test "only acts on trips still in the building state" do
    trip = @user.owned_trips.create!(
      title: "Done", destination: "X", start_date: Date.current, end_date: Date.current,
      build_status: "ready"
    )
    BuildTripJob.perform_now(trip.id)
    assert_equal 0, trip.reload.trip_days.size, "ready trips are left untouched"
  end
end
