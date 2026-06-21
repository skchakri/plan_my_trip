require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  Act = Struct.new(:latitude, :longitude, :address)
  Day = Struct.new(:activities)

  test "day_directions_url builds a multi-stop maps directions link from coords" do
    day = Day.new([ Act.new(36.1, -115.1, nil), Act.new(36.2, -115.2, nil) ])
    url = day_directions_url(day)
    assert_includes url, "https://www.google.com/maps/dir/?api=1"
    assert_includes url, "destination=36.2%2C-115.2"
    assert_includes url, "waypoints=36.1%2C-115.1"
  end

  test "day_directions_url falls back to a street address when coords are missing" do
    day = Day.new([ Act.new(nil, nil, "350 5th Ave, New York") ])
    url = day_directions_url(day)
    assert_includes url, "destination=350+5th+Ave%2C+New+York"
    refute_includes url, "waypoints="
  end

  test "day_directions_url is nil when no activity has a location" do
    day = Day.new([ Act.new(nil, nil, nil) ])
    assert_nil day_directions_url(day)
  end
end
