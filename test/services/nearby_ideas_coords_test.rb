require "test_helper"

# Focused on NearbyIdeas#verified_coords — the coordinate-truth guard that
# only spends a geocode when the model's lat/lng is missing or implausibly
# far, and only adopts a geocoded point when it's actually within reach.
class NearbyIdeasCoordsTest < ActiveSupport::TestCase
  # Test seam: a NearbyIdeas whose geocoder is a canned answer + a call
  # counter, so we never touch the network (matching the suite's no-mock
  # convention — Minitest 6 dropped Object#stub).
  class FakeGeoIdeas < NearbyIdeas
    attr_reader :geocode_calls

    def initialize(geo:, **opts)
      super(**opts)
      @geo = geo
      @geocode_calls = 0
    end

    private

    def lookup_geocode(_name)
      @geocode_calls += 1
      @geo
    end
  end

  # Anchor: Salt Lake City, 80 km radius.
  def service(geo: nil)
    FakeGeoIdeas.new(
      geo: geo, anchor_label: "Salt Lake City",
      lat: 40.7608, lng: -111.8910, radius_km: 80
    )
  end

  test "plausible in-radius coordinates are kept and no geocode is spent" do
    svc = service(geo: hit(0, 0)) # geo would be returned, but shouldn't be consulted
    lat, lng, dist = svc.send(:verified_coords, "Some Park", 40.85, -111.95)
    assert_equal 40.85, lat
    assert_equal(-111.95, lng)
    assert dist < 80
    assert_equal 0, svc.geocode_calls, "should not geocode coords already in range"
    assert_equal NearbyIdeas::GEOCODE_BUDGET, svc.instance_variable_get(:@geocode_budget)
  end

  test "missing coordinates are filled from a geocoded hit within range" do
    svc = service(geo: hit(40.63, -111.69))
    lat, lng, dist = svc.send(:verified_coords, "Donut Falls", nil, nil)
    assert_equal 40.63, lat
    assert_equal(-111.69, lng)
    assert dist.positive?
    assert_equal 1, svc.geocode_calls
    assert_equal NearbyIdeas::GEOCODE_BUDGET - 1, svc.instance_variable_get(:@geocode_budget)
  end

  test "wildly out-of-range model coords are replaced when geocode lands in range" do
    svc = service(geo: hit(40.63, -111.69))
    lat, _lng, dist = svc.send(:verified_coords, "Real Spot", 33.4, -112.0) # ~1500 km off
    assert_equal 40.63, lat
    assert dist <= 80 * NearbyIdeas::GEOCODE_OUT_OF_RANGE_FACTOR
  end

  test "a geocode that also lands out of range is rejected in favor of model coords" do
    svc = service(geo: hit(33.4, -112.0)) # Phoenix — also far
    lat, lng, _dist = svc.send(:verified_coords, "Ambiguous Name", 33.5, -112.1)
    assert_equal 33.5, lat
    assert_equal(-112.1, lng)
  end

  test "a nil geocode keeps the original model coordinates" do
    svc = service(geo: nil)
    lat, lng, _dist = svc.send(:verified_coords, "Unfindable", 33.5, -112.1)
    assert_equal 33.5, lat
    assert_equal(-112.1, lng)
  end

  test "geocode budget caps how many suspect picks hit the network" do
    svc = service(geo: nil)
    (NearbyIdeas::GEOCODE_BUDGET + 3).times do
      svc.send(:verified_coords, "Far Place", 10.0, 10.0) # always out of range
    end
    assert_equal NearbyIdeas::GEOCODE_BUDGET, svc.geocode_calls
  end

  private

  def hit(lat, lng)
    Places::Geocoder::Result.new(lat: lat, lng: lng, display_name: "x")
  end
end
