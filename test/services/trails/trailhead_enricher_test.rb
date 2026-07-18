require "test_helper"

class Trails::TrailheadEnricherTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "O")
    @trip = @owner.owned_trips.create!(title: "Utah", destination: "Zion",
                                       anchor_lat: 37.30, anchor_lng: -113.03,
                                       start_date: Date.current, end_date: Date.current + 2)
    @trail = @trip.trails.create!(name: "Angels Landing", position: 0)
  end

  test "call stores geocoded coords + elevation and stamps enriched_at" do
    enricher = Trails::TrailheadEnricher.new(@trail)
    def enricher.geocode = [ 37.2690, -112.9469 ]
    def enricher.elevation_feet(_lat, _lng) = 5790
    enricher.call

    @trail.reload
    assert_in_delta 37.2690, @trail.trailhead_lat.to_f, 0.0001
    assert_in_delta(-112.9469, @trail.trailhead_lng.to_f, 0.0001)
    assert_equal 5790, @trail.trailhead_elevation_ft
    assert @trail.enriched_at.present?
  end

  test "no elevation lookup happens when geocoding fails, but enriched_at is stamped" do
    enricher = Trails::TrailheadEnricher.new(@trail)
    def enricher.geocode = [ nil, nil ]
    def enricher.elevation_feet(*) = raise("should not be called")
    enricher.call

    @trail.reload
    assert_nil @trail.trailhead_lat
    assert_nil @trail.trailhead_elevation_ft
    assert @trail.enriched_at.present? # so we don't retry in a tight loop
  end

  test "an exception is rescued and still stamps enriched_at" do
    enricher = Trails::TrailheadEnricher.new(@trail)
    def enricher.geocode = raise("boom")
    assert_nothing_raised { enricher.call }
    assert @trail.reload.enriched_at.present?
  end
end
