require "test_helper"

class TripKmlBuilderTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "kml-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Kim")
    @trip = @user.owned_trips.create!(
      title: "Vegas & Utah", destination: "Las Vegas, NV",
      start_date: Date.new(2026, 8, 1), end_date: Date.new(2026, 8, 3)
    )
  end

  def add_day(position:, title: "Day title", activities: [])
    day = @trip.trip_days.create!(title: title, label: "Day #{position}", accent: "gold", position: position)
    activities.each_with_index { |attrs, i| day.activities.create!(position: i, **attrs) }
    day
  end

  test "emits one folder per day with lng,lat placemarks and XML-escaped names" do
    add_day(position: 1, title: "Strip & shows", activities: [
      { title: "Bellagio Fountains & Gardens", latitude: 36.1127, longitude: -115.1740,
        time_label: "7:00 PM", famous_for: "Choreographed water show" },
      { title: "No coordinates yet", latitude: nil, longitude: nil }
    ])
    kml = TripKmlBuilder.new(@trip).to_kml

    assert_includes kml, "<name>Vegas &amp; Utah</name>"
    assert_includes kml, "<name>Day 1 — Strip &amp; shows</name>"
    assert_includes kml, "<name>Bellagio Fountains &amp; Gardens</name>"
    assert_includes kml, "<coordinates>-115.174,36.1127</coordinates>", "KML must be lng,lat"
    assert_includes kml, "7:00 PM"
    refute_includes kml, "No coordinates yet", "coordinate-less activities are noise on a map"
  end

  test "days with no mappable stops are omitted; landmarks get their own folder" do
    add_day(position: 1, activities: [ { title: "Unmapped", latitude: nil, longitude: nil } ])
    @trip.route_landmarks.create!(
      name: "Hoover Dam", kind: "engineering", source: "seed",
      latitude: 36.0161, longitude: -114.7377, narration: "Big dam."
    )
    kml = TripKmlBuilder.new(@trip).to_kml

    refute_includes kml, "<Folder>\n<name>Day 1"
    assert_includes kml, "<name>En-route landmarks</name>"
    assert_includes kml, "<name>Hoover Dam</name>"
    assert_includes kml, "<coordinates>-114.7377,36.0161</coordinates>"
  end

  test "a bare trip still produces a valid document shell" do
    kml = TripKmlBuilder.new(@trip).to_kml
    assert_includes kml, %(<kml xmlns="http://www.opengis.net/kml/2.2">)
    assert_includes kml, "</Document>"
    refute_includes kml, "<Placemark>"
  end
end
