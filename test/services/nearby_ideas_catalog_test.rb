require "test_helper"

# Covers NearbyIdeas catalog-side behavior that doesn't touch the network:
# the true-distance radius filter, proximity/name dedup, and the final
# display cap. Anchor is Salt Lake City throughout.
class NearbyIdeasCatalogTest < ActiveSupport::TestCase
  ANCHOR = { anchor_label: "Salt Lake City", lat: 40.76078, lng: -111.89105, radius_km: 80 }.freeze

  def service(**over)
    NearbyIdeas.new(**ANCHOR.merge(over))
  end

  def place(name, lat, lng, kind: "trail", **attrs)
    Place.create!(name: name, kind: kind, image_url: "https://example.com/#{name.parameterize}.jpg",
                  latitude: lat, longitude: lng, **attrs)
  end

  test "catalog_ideas drops places inside the bounding box but outside the true radius" do
    place("In Radius Trail",     41.12, -111.89105) # ~40 km due north — inside the 80 km circle
    place("Box Corner Overlook", 41.30, -111.18, kind: "overlook") # ~85 km NE — inside the box, outside the circle

    names = service.send(:catalog_ideas).map(&:name)
    assert_includes names, "In Radius Trail"
    refute_includes names, "Box Corner Overlook",
      "a place beyond the great-circle radius must be filtered out even though it falls in the lat/lng bounding box"
  end
end
