require "test_helper"

class Places::GeocoderTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "too-short queries short-circuit without a lookup" do
    assert_nil Places::Geocoder.call("ab")
  end

  test "returns a Result from a cached hit without touching the network" do
    geo = Places::Geocoder.new("Donut Falls", near_lat: 40.76, near_lng: -111.89)
    Rails.cache.write(
      geo.send(:cache_key),
      { "lat" => 40.63, "lng" => -111.69, "display_name" => "Donut Falls, Utah" }
    )

    result = geo.call
    assert_equal 40.63, result.lat
    assert_equal(-111.69, result.lng)
    assert_equal "Donut Falls, Utah", result.display_name
  end

  test "a cached negative lookup returns nil" do
    geo = Places::Geocoder.new("Nowhere At All", near_lat: 40.76, near_lng: -111.89)
    Rails.cache.write(geo.send(:cache_key), :miss)
    assert_nil geo.call
  end

  test "google_lookup is a no-op when no Google Places key is configured" do
    geo = Places::Geocoder.new("Donut Falls", near_lat: 40.76, near_lng: -111.89)
    assert_nil AppSetting.get("GOOGLE_PLACES_API_KEY"), "precondition: no key set in test"
    assert_nil geo.send(:google_lookup), "without a key, Google path must short-circuit (no network)"
  end

  test "fetch falls back to Nominatim when Google is unconfigured" do
    # With no Google key, fetch delegates straight to nominatim_lookup. We stub
    # that seam so there's no real network call.
    geo = Places::Geocoder.new("Donut Falls", near_lat: 40.76, near_lng: -111.89)
    def geo.nominatim_lookup = { "lat" => 40.63, "lng" => -111.69, "display_name" => "Donut Falls (OSM)" }
    result = geo.send(:fetch)
    assert_equal 40.63, result["lat"]
    assert_equal "Donut Falls (OSM)", result["display_name"]
  end

  test "viewbox brackets the anchor as left,top,right,bottom" do
    geo = Places::Geocoder.new("X", near_lat: 40.0, near_lng: -111.0, bias_km: 111)
    left, top, right, bottom = geo.send(:viewbox).split(",").map(&:to_f)
    assert left < -111.0 && right > -111.0, "longitude should bracket the anchor"
    assert bottom < 40.0 && top > 40.0, "latitude should bracket the anchor"
    assert_in_delta 1.0, top - 40.0, 0.01, "~1 degree lat for 111 km"
  end
end
