require "test_helper"

class RoadTripEstimatorTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @user = User.create!(email: "rte-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Roady")
    @trip = @user.owned_trips.create!(
      title: "Utah loop", transport_mode: "own_car",
      start_date: Date.current, end_date: Date.current + 2
    )
  end

  teardown do
    Rails.cache = @original_cache
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  # Add a day with `coords` activities (each [lat, lng, name]).
  def add_day(trip, coords, label: "Day 1")
    day = trip.trip_days.create!(title: label, label: label, accent: "gold", position: trip.trip_days.count + 1)
    coords.each_with_index do |(lat, lng, name), i|
      day.activities.create!(title: name || "Stop #{i + 1}", location_name: name, latitude: lat, longitude: lng, position: i)
    end
    day
  end

  # An estimator whose OSRM seam returns canned legs and counts its calls.
  def estimator_with_route(trip, legs:, viewer: nil)
    est = RoadTripEstimator.new(trip, viewer: viewer)
    calls = []
    est.define_singleton_method(:fetch_osrm) do |coords|
      calls << coords
      legs
    end
    [ est, calls ]
  end

  # 1 meter ≈ a known mile figure: 160934.4 m == 100 miles, 1609.344 m == 1 mile.
  def leg(distance_m, duration_s)
    { "distance" => distance_m, "duration" => duration_s }
  end

  # ── Guards ───────────────────────────────────────────────────────────

  test "returns nil when the trip is not own_car" do
    @trip.update!(transport_mode: "rental")
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ] ])
    assert_nil RoadTripEstimator.call(@trip)
  end

  test "returns nil with fewer than two geocoded stops" do
    add_day(@trip, [ [ 40.0, -111.0, "A" ] ])
    est, calls = estimator_with_route(@trip, legs: [])
    assert_nil est.call
    assert_empty calls, "OSRM must not be called with a single waypoint"
  end

  test "ignores stops without coordinates" do
    day = @trip.trip_days.create!(title: "D", label: "D", accent: "gold", position: 1)
    day.activities.create!(title: "No coords", position: 0)
    day.activities.create!(title: "Has coords", latitude: 40.0, longitude: -111.0, position: 1)
    est, calls = estimator_with_route(@trip, legs: [])
    assert_nil est.call, "one valid waypoint isn't enough to route"
    assert_empty calls
  end

  # ── Core math ────────────────────────────────────────────────────────

  test "computes per-leg miles, drive time, and fuel cost plus totals" do
    add_day(@trip, [ [ 40.0, -111.0, "Home" ], [ 41.0, -112.0, "Park" ], [ 42.0, -113.0, "Lake" ] ])
    # 100 miles in 1h, then 50 miles in 0.5h.
    legs = [ leg(160_934.4, 3600), leg(80_467.2, 1800) ]
    est, calls = estimator_with_route(@trip, legs: legs)

    result = est.call
    assert_equal 1, calls.size, "one OSRM call routes the whole list"
    assert_equal 2, result.legs.size

    assert_in_delta 100.0, result.legs[0].miles, 0.01
    assert_equal 3600, result.legs[0].drive_seconds
    assert_equal "Home", result.legs[0].from
    assert_equal "Park", result.legs[0].to
    # default 25 mpg, fallback $3.40/gal → 100/25*3.40 = 13.60
    assert_in_delta 13.60, result.legs[0].fuel_cost, 0.01
    assert_in_delta 6.80, result.legs[1].fuel_cost, 0.01

    assert_in_delta 150.0, result.total_miles, 0.01
    assert_equal 5400, result.total_drive_seconds
    assert_in_delta 20.40, result.total_fuel_cost, 0.01
  end

  test "uses the trip's vehicle_mpg when set and marks it non-estimated" do
    @trip.update!(vehicle_mpg: 50)
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ] ])
    est, _ = estimator_with_route(@trip, legs: [ leg(160_934.4, 3600) ])

    result = est.call
    assert_equal 50.0, result.mpg
    refute result.mpg_estimated
    # 100 miles / 50 mpg * 3.40 = 6.80
    assert_in_delta 6.80, result.total_fuel_cost, 0.01
  end

  test "falls back to the default mpg and flags it when vehicle_mpg is blank" do
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ] ])
    est, _ = estimator_with_route(@trip, legs: [ leg(160_934.4, 3600) ])

    result = est.call
    assert_equal RoadTripEstimator::DEFAULT_MPG, result.mpg
    assert result.mpg_estimated
  end

  # ── Fuel price ───────────────────────────────────────────────────────

  test "uses the fallback price labelled 'estimate' when no EIA key is set" do
    assert_nil AppSetting.get("EIA_API_KEY"), "precondition: no EIA key in test"
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ] ])
    est, _ = estimator_with_route(@trip, legs: [ leg(160_934.4, 3600) ])

    result = est.call
    assert_equal RoadTripEstimator::DEFAULT_PRICE_PER_GALLON, result.price_per_gallon
    assert_equal "estimate", result.price_source
  end

  test "uses the live EIA price when a key is configured" do
    AppSetting.set("EIA_API_KEY", "test-key")
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ] ])
    est, _ = estimator_with_route(@trip, legs: [ leg(160_934.4, 3600) ])
    est.define_singleton_method(:fetch_eia_price) { |_key| 4.00 }

    result = est.call
    assert_equal 4.00, result.price_per_gallon
    assert_equal "eia", result.price_source
    # 100 miles / 25 mpg * 4.00 = 16.00
    assert_in_delta 16.00, result.total_fuel_cost, 0.01
  ensure
    AppSetting.set("EIA_API_KEY", "")
  end

  # ── Resilience ───────────────────────────────────────────────────────

  test "returns nil when OSRM routing fails" do
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ] ])
    est, _ = estimator_with_route(@trip, legs: nil) # simulates a rescued failure
    assert_nil est.call
  end

  test "returns nil when OSRM returns the wrong number of legs" do
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ], [ 42.0, -113.0, "C" ] ])
    est, _ = estimator_with_route(@trip, legs: [ leg(1000, 60) ]) # 1 leg for 3 waypoints
    assert_nil est.call
  end

  test "a cached route avoids a second OSRM call" do
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 41.0, -112.0, "B" ] ])

    est1, calls1 = estimator_with_route(@trip, legs: [ leg(160_934.4, 3600) ])
    assert est1.call
    assert_equal 1, calls1.size

    # A fresh instance for the same itinerary hits the route cache.
    est2, calls2 = estimator_with_route(@trip, legs: [ leg(999_999, 9999) ])
    result = est2.call
    assert_empty calls2, "second estimate should be served from cache"
    assert_in_delta 100.0, result.total_miles, 0.01, "cached value wins, not the new stub"
  end

  # ── Waypoints ────────────────────────────────────────────────────────

  test "dedupes consecutive identical coordinates" do
    add_day(@trip, [ [ 40.0, -111.0, "A" ], [ 40.0, -111.0, "A again" ], [ 41.0, -112.0, "B" ] ])
    est, calls = estimator_with_route(@trip, legs: [ leg(160_934.4, 3600) ])
    result = est.call
    assert result, "should route the two distinct waypoints"
    assert_equal 2, calls.first.size, "the duplicate stop is collapsed to one waypoint"
  end

  test "caps waypoints and flags the result as partial" do
    coords = (0...40).map { |i| [ 40.0 + i * 0.1, -111.0 - i * 0.1, "S#{i}" ] }
    add_day(@trip, coords)
    legs = Array.new(RoadTripEstimator::MAX_WAYPOINTS - 1) { leg(1609.344, 60) }
    est, calls = estimator_with_route(@trip, legs: legs)

    result = est.call
    assert result.partial, "over-cap itineraries are flagged approximate"
    assert_equal RoadTripEstimator::MAX_WAYPOINTS, calls.first.size
  end

  test "prepends the geocoded origin as the first waypoint" do
    @trip.update!(origin: "Salt Lake City")
    add_day(@trip, [ [ 40.5, -111.5, "Park" ], [ 41.0, -112.0, "Lake" ] ])

    est, calls = estimator_with_route(@trip, legs: [ leg(1000, 60), leg(1000, 60) ])
    # Stub the geocoder seam so the test doesn't hit the network.
    est.define_singleton_method(:origin_waypoint) do
      { name: "Salt Lake City", lat: 40.76, lng: -111.89, coord: "-111.89,40.76" }
    end

    result = est.call
    assert_equal 2, result.legs.size, "origin + 2 stops = 3 waypoints = 2 legs"
    assert_equal "Salt Lake City", result.legs.first.from
    assert_equal 3, calls.first.size
  end
end
