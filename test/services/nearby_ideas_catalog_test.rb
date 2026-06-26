require "test_helper"

# Covers NearbyIdeas catalog-side behavior that doesn't touch the network:
# the true-distance radius filter, proximity/name dedup, and the final
# display cap. Anchor is Salt Lake City throughout.
class NearbyIdeasCatalogTest < ActiveSupport::TestCase
  ANCHOR = { anchor_label: "Salt Lake City", lat: 40.76078, lng: -111.89105, radius_km: 80 }.freeze

  # No-network seam: catalog only, mirroring the FakeGeoIdeas pattern in
  # nearby_ideas_coords_test.rb (Minitest 6 dropped Object#stub).
  class CatalogOnlyIdeas < NearbyIdeas
    private

    def claude_research_ideas = []
  end

  def service(**over)
    NearbyIdeas.new(**ANCHOR.merge(over))
  end

  def catalog_only_service(**over)
    CatalogOnlyIdeas.new(**ANCHOR.merge(over))
  end

  def place(name, lat, lng, kind: "trail", **attrs)
    Place.create!(name: name, kind: kind, image_url: "https://example.com/#{name.parameterize}.jpg",
                  latitude: lat, longitude: lng, **attrs)
  end

  def idea(name, lat, lng)
    NearbyIdeas::Idea.new(slug: name.parameterize, name: name, latitude: lat, longitude: lng)
  end

  # --- Fix 2: true-distance radius filter --------------------------------

  test "catalog_ideas drops places inside the bounding box but outside the true radius" do
    place("In Radius Trail",     41.12, -111.89105) # ~40 km due north — inside the 80 km circle
    place("Box Corner Overlook", 41.30, -111.18, kind: "overlook") # ~85 km NE — inside the box, outside the circle

    names = service.send(:catalog_ideas).map(&:name)
    assert_includes names, "In Radius Trail"
    refute_includes names, "Box Corner Overlook",
      "a place beyond the great-circle radius must be filtered out even though it falls in the lat/lng bounding box"
  end

  # --- Fix 1: proximity + name-subsumption dedup -------------------------

  test "dedupe_same_place collapses name-subset duplicates, keeping the first (best-ranked)" do
    ideas = [
      idea("Great Salt Lake",            41.10, -112.20),
      idea("Great Salt Lake State Park", 40.99, -112.21), # word-set superset of #1, far apart
      idea("Spiral Jetty",               41.44, -112.66),
      idea("Spiral Jetty Viewing Area",  41.4405, -112.6605), # subset name AND co-located
      idea("Lake Mary Trail",            40.60, -111.64)  # distinct
    ]
    kept = catalog_only_service.send(:dedupe_same_place, ideas).map(&:name)
    assert_equal [ "Great Salt Lake", "Spiral Jetty", "Lake Mary Trail" ], kept
  end

  test "dedupe_same_place merges co-located ideas even with unrelated names" do
    ideas = [
      idea("Spiral Jetty", 41.44, -112.66),
      idea("Rozel Point",  41.4402, -112.6603) # ~30 m away, different name
    ]
    assert_equal [ "Spiral Jetty" ], catalog_only_service.send(:dedupe_same_place, ideas).map(&:name)
  end

  test "dedupe_same_place keeps distinct places that are neither co-located nor name-subsets" do
    ideas = [
      idea("Bell's Canyon Lower Falls", 40.56, -111.80),
      idea("Bell's Canyon Upper Falls", 40.60, -111.80), # ~4.4 km from #1, 'upper' vs 'lower'
      idea("Cecret Lake",               40.57, -111.62)
    ]
    assert_equal 3, catalog_only_service.send(:dedupe_same_place, ideas).length
  end

  # --- Fix 4: long-haul flagging ----------------------------------------

  test "Idea#long_haul? flags drives at or over the threshold" do
    assert NearbyIdeas::Idea.new(name: "x", slug: "x", drive_minutes: 100).long_haul?
    assert_not NearbyIdeas::Idea.new(name: "x", slug: "x", drive_minutes: 35).long_haul?
  end

  test "Idea#long_haul? falls back to distance_km when drive time is blank" do
    assert NearbyIdeas::Idea.new(name: "x", slug: "x", distance_km: 95).long_haul?
    assert_not NearbyIdeas::Idea.new(name: "x", slug: "x", distance_km: 20).long_haul?
  end

  test "fetch_ideas collapses duplicate catalog rows for the same place" do
    place("Great Salt Lake",            41.10, -112.20, kind: "natural")
    place("Great Salt Lake State Park", 40.99, -112.21, kind: "park")
    place("Lake Mary Trail",            40.60, -111.64, kind: "trail")

    names = catalog_only_service.send(:fetch_ideas).map(&:name)
    assert_includes names, "Lake Mary Trail"
    assert_equal 1, names.count { |n| n.include?("Great Salt Lake") },
      "the two Great Salt Lake catalog rows should collapse to a single idea"
  end

  # --- Fix 5: trim padding with a display cap ----------------------------

  test "fetch_ideas caps the result at the display limit instead of padding" do
    # 16 distinct, in-radius, >2 km-spaced catalog rows — none dedup away.
    16.times { |i| place(format("Catalog Spot %02d", i), 40.50 + i * 0.03, -111.89105) }

    result = catalog_only_service.send(:fetch_ideas)
    assert_equal NearbyIdeas::DISPLAY_LIMIT, result.length,
      "should return a curated set capped at DISPLAY_LIMIT, not all 16"
  end
end
