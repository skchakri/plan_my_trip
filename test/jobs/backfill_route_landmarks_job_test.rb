require "test_helper"

# Route landmarks run on the slow web-search provider and used to block the
# build; they're now generated here, off the critical path. RouteLandmarksBuilder
# is swapped for a fake (no network) to assert the orchestration: it runs only
# when there's an origin to drive from, and derives stops from persisted
# activities.
class BackfillRouteLandmarksJobTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "rl-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Rex")
  end

  def with_fake_builder
    calls = []
    original = RouteLandmarksBuilder.method(:call)
    RouteLandmarksBuilder.singleton_class.send(:define_method, :call) do |**kwargs|
      calls << kwargs
      []
    end
    yield calls
  ensure
    RouteLandmarksBuilder.singleton_class.send(:define_method, :call, original)
  end

  def trip_with_stops(origin:)
    trip = @user.owned_trips.create!(title: "T", destination: "Hanksville, UT", origin: origin,
                                     start_date: Date.current, end_date: Date.current, build_status: "ready")
    day = trip.trip_days.create!(label: "day-1", title: "Day 1", accent: "blue", position: 0, date: trip.start_date)
    day.activities.create!(title: "Goblin Valley", location_name: "Goblin Valley", latitude: 38.56, longitude: -110.70, position: 0)
    day.activities.create!(title: "No coords stop", location_name: "No coords stop", position: 1)
    trip
  end

  test "builds landmarks from coordinate-bearing stops when there's an origin" do
    trip = trip_with_stops(origin: "Salt Lake City, UT")
    with_fake_builder do |calls|
      BackfillRouteLandmarksJob.perform_now(trip.id)
      assert_equal 1, calls.size
      stops = calls.first[:itinerary_stops]
      assert_equal [ "Goblin Valley" ], stops.map { |s| s[:name] } # only the one with coords
      assert_equal "Salt Lake City, UT", calls.first[:origin]
    end
  end

  test "skips entirely when the trip has no origin to drive from" do
    trip = trip_with_stops(origin: nil)
    with_fake_builder do |calls|
      BackfillRouteLandmarksJob.perform_now(trip.id)
      assert_empty calls
    end
  end

  test "missing trip is a no-op" do
    assert_nothing_raised { BackfillRouteLandmarksJob.perform_now(SecureRandom.uuid) }
  end
end
