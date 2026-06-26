require "test_helper"

# PlaceRanker composite scoring. Focused here on the distance component:
# long-haul (full-day) day-trip picks must fall off steeply so a 100 km
# outlier can't sit alongside a 15 km one as an interchangeable "stop".
class PlaceRankerTest < ActiveSupport::TestCase
  def item(name:, **attrs)
    NearbyIdeas::Idea.new(name: name, slug: name, **attrs)
  end

  test "distance score falls off steeply for long-haul picks" do
    items = [ item(name: "near", distance_km: 15), item(name: "far", distance_km: 100) ]
    PlaceRanker.rank!(items, anchor_lat: 40.76, anchor_lng: -111.89)
    near = items.find { |i| i.name == "near" }
    far  = items.find { |i| i.name == "far" }

    assert_operator near.score_breakdown[:distance], :>=, 15.0,
      "a 15 km pick should still score strongly on distance"
    assert_operator far.score_breakdown[:distance], :<=, 3.0,
      "a 100 km pick should sink well below the old flat 5.0 floor"
  end

  test "a far pick ranks below an otherwise-comparable near pick" do
    near = item(name: "near", distance_km: 20, category: "scenic")
    far  = item(name: "far",  distance_km: 100, category: "scenic")
    ranked = PlaceRanker.rank!([ far, near ], interests: [ "scenic" ], anchor_lat: 40.76, anchor_lng: -111.89)
    assert_equal "near", ranked.first.name
  end
end
