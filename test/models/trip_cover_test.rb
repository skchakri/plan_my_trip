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

  test "cover_palette_index is stable across loads" do
    a = @trip.cover_palette_index
    b = Trip.find(@trip.id).cover_palette_index
    assert_equal a, b
    assert_includes 0..6, a
  end
end
