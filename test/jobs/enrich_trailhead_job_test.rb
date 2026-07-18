require "test_helper"

class EnrichTrailheadJobTest < ActiveJob::TestCase
  test "no-ops when the trail no longer exists" do
    assert_nothing_raised { EnrichTrailheadJob.perform_now(SecureRandom.uuid) }
  end

  test "delegates to the enricher for an existing trail (no network)" do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "O")
    trip = owner.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 1)
    trail = trip.trails.create!(name: "Mist Trail", position: 0)

    # Seed a cached geocode miss so the enricher's Places::Geocoder call returns
    # nil without touching Nominatim, and no elevation lookup fires either.
    geo = Places::Geocoder.new("Mist Trail", near_lat: nil, near_lng: nil)
    Rails.cache.write(geo.send(:cache_key), :miss)

    EnrichTrailheadJob.perform_now(trail.id)

    trail.reload
    assert trail.enriched_at.present?
    assert_nil trail.trailhead_lat
  ensure
    Rails.cache = @original_cache
  end
end
