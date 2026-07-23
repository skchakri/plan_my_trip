require "test_helper"

class TripCoverTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "c-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Owner")
    @trip = @owner.owned_trips.create!(title: "Vegas", start_date: Date.current, end_date: Date.current + 2)
    @day = @trip.trip_days.create!(label: "day-1", title: "Drive", accent: "blue", position: 1)
  end

  test "cover_image_url is nil when no images exist anywhere" do
    @day.activities.create!(title: "Just a stop", position: 1)
    assert_nil @trip.reload.cover_image_url
  end

  test "cover_image_url falls back to a route landmark image" do
    @day.activities.create!(title: "Plain stop", position: 1)
    @trip.route_landmarks.create!(
      name: "Hoover Dam", kind: "scenic",
      latitude: 36.0, longitude: -114.7,
      narration: "Concrete monolith", position: 1,
      image_url: "https://example.com/hoover.jpg"
    )
    assert_equal "https://example.com/hoover.jpg", @trip.reload.cover_image_url
  end

  test "activity photo_url wins over a landmark image" do
    @day.activities.create!(title: "Strip", position: 1, photo_url: "https://example.com/strip.jpg")
    @trip.route_landmarks.create!(
      name: "Hoover Dam", kind: "scenic",
      latitude: 36.0, longitude: -114.7,
      narration: "x", position: 1,
      image_url: "https://example.com/hoover.jpg"
    )
    assert_equal "https://example.com/strip.jpg", @trip.reload.cover_image_url
  end

  # The dashboard bug: on a drive trip the first stop is "Depart <origin>", so
  # every trip leaving the same city wore that city's photo. The cover must
  # represent the DESTINATION, not the departure.
  test "the origin departure stop is never the cover" do
    trip = @owner.owned_trips.create!(
      title: "Moab", destination: "Moab, Utah", origin: "Salt Lake City, UT",
      start_date: Date.current, end_date: Date.current + 2
    )
    d1 = trip.trip_days.create!(label: "day-1", title: "Drive in", accent: "blue", position: 1)
    slc = Place.create!(name: "Salt Lake City, UT", kind: "drive_segment")
    d1.activities.create!(title: "Depart Salt Lake City", position: 1, place: slc,
                          location_name: "Salt Lake City, UT", photo_url: "https://example.com/slc.jpg")
    arches = Place.create!(name: "Arches National Park", kind: "trail")
    d1.activities.create!(title: "Enter Arches National Park", position: 2, place: arches,
                          location_name: "Arches National Park", photo_url: "https://example.com/arches.jpg")

    assert_equal "https://example.com/arches.jpg", trip.reload.cover_image_url
  end

  test "a sight is preferred over a destination-area meal" do
    trip = @owner.owned_trips.create!(
      title: "Moab", destination: "Moab, Utah", origin: "Salt Lake City, UT",
      start_date: Date.current, end_date: Date.current + 2
    )
    d1 = trip.trip_days.create!(label: "day-1", title: "In town", accent: "gold", position: 1)
    diner = Place.create!(name: "Moab Diner", kind: "restaurant")
    d1.activities.create!(title: "Lunch at Moab Diner", position: 1, place: diner,
                          location_name: "Moab Diner", photo_url: "https://example.com/diner.jpg")
    park = Place.create!(name: "Canyonlands", kind: "trail")
    d1.activities.create!(title: "Grand View Point", position: 2, place: park,
                          location_name: "Grand View Point, Canyonlands", photo_url: "https://example.com/canyon.jpg")

    assert_equal "https://example.com/canyon.jpg", trip.reload.cover_image_url
  end

  test "a destination-named sight beats an unrelated en-route sight" do
    trip = @owner.owned_trips.create!(
      title: "Moab", destination: "Moab, Utah", origin: "Salt Lake City, UT",
      start_date: Date.current, end_date: Date.current + 2
    )
    d1 = trip.trip_days.create!(label: "day-1", title: "Drive in", accent: "teal", position: 1)
    green = Place.create!(name: "Green River overlook", kind: "viewpoint")
    d1.activities.create!(title: "Stretch at Green River", position: 1, place: green,
                          location_name: "Green River, UT", photo_url: "https://example.com/green.jpg")
    moab = Place.create!(name: "Moab Main Street", kind: "landmark")
    d1.activities.create!(title: "Stroll Main Street", position: 2, place: moab,
                          location_name: "Moab Main Street", photo_url: "https://example.com/moab.jpg")

    assert_equal "https://example.com/moab.jpg", trip.reload.cover_image_url
  end

  test "an all-transit trip still shows an image rather than nil" do
    trip = @owner.owned_trips.create!(
      title: "Long haul", destination: "Reno, NV", origin: "Salt Lake City, UT",
      start_date: Date.current, end_date: Date.current + 1
    )
    d1 = trip.trip_days.create!(label: "day-1", title: "Drive", accent: "rose", position: 1)
    slc = Place.create!(name: "Salt Lake City, UT", kind: "drive_segment")
    d1.activities.create!(title: "Depart Salt Lake City", position: 1, place: slc,
                          location_name: "Salt Lake City, UT", photo_url: "https://example.com/slc.jpg")

    assert_equal "https://example.com/slc.jpg", trip.reload.cover_image_url
  end

  test "cover_palette_index is stable across loads" do
    a = @trip.cover_palette_index
    b = Trip.find(@trip.id).cover_palette_index
    assert_equal a, b
    assert_includes 0..6, a
  end
end
