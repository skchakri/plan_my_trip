require "test_helper"

class RoadTripTest < ActiveSupport::TestCase
  test "auto-generates a slug from origin and destination" do
    rt = RoadTrip.create!(origin: "San Francisco", destination: "Las Vegas", title: "SF to LV")
    assert_equal "san-francisco-to-las-vegas", rt.slug
  end

  test "published scope excludes drafts and discarded rows" do
    live  = RoadTrip.create!(origin: "A", destination: "B", title: "AB", status: "published")
    draft = RoadTrip.create!(origin: "C", destination: "D", title: "CD", status: "draft")
    gone  = RoadTrip.create!(origin: "E", destination: "F", title: "EF", status: "published")
    gone.discard

    slugs = RoadTrip.published.pluck(:slug)
    assert_includes slugs, live.slug
    refute_includes slugs, draft.slug
    refute_includes slugs, gone.slug
  end

  test "jsonb fields always read back as arrays" do
    rt = RoadTrip.create!(origin: "A", destination: "B", title: "AB",
                          stops: [ { "name" => "Stop 1", "blurb" => "b" } ],
                          itinerary: [ { "day" => 1, "title" => "Day 1" } ],
                          faqs: [ { "q" => "Q?", "a" => "A." } ])
    assert_equal 1, rt.stops.size
    assert_equal "Stop 1", rt.stops.first["name"]
    assert_equal 1, rt.itinerary.size
    assert_equal 1, rt.faqs.size
    assert_equal "A → B", rt.corridor
    assert_equal rt.slug, rt.to_param
  end

  test "rejects a malformed slug" do
    rt = RoadTrip.new(origin: "A", destination: "B", title: "T", slug: "Bad Slug!")
    refute rt.valid?
  end
end
