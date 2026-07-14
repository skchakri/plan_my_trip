require "test_helper"

# GET /trips/:id/stops.kml — the Google My Maps hand-off download.
class Trips::StopsKmlTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "sk-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Sam")
    @trip = @user.owned_trips.create!(
      title: "Vegas run", destination: "Las Vegas, NV",
      start_date: Date.current + 3, end_date: Date.current + 5
    )
    day = @trip.trip_days.create!(title: "Arrival", label: "Day 1", accent: "gold", position: 1)
    day.activities.create!(title: "Bellagio", latitude: 36.1127, longitude: -115.1740, position: 0)
    sign_in_as(@user)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  test "downloads a KML attachment with the trip's stops" do
    get stops_trip_path(@trip, format: :kml)
    assert_response :success
    assert_match %r{application/vnd\.google-earth\.kml\+xml}, response.content_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/vegas-run-stops\.kml/, response.headers["Content-Disposition"])
    assert_includes response.body, "<name>Bellagio</name>"
    assert_includes response.body, "<coordinates>-115.174,36.1127</coordinates>"
  end

  test "plan page renders the KML links with Turbo disabled" do
    # A download response never fires turbo:load, so a Turbo-driven click
    # leaves the loading-spinner overlay up forever.
    get plan_trip_path(@trip)
    assert_response :success
    kml_links = response.body.scan(/<a [^>]*>/).select { |a| a.include?(stops_trip_path(@trip, format: :kml)) }
    assert kml_links.size >= 2, "expected the popover + map-modal KML links"
    kml_links.each { |a| assert_includes a, 'data-turbo="false"', "KML link must opt out of Turbo: #{a}" }
  end

  test "requires trip access" do
    outsider = User.create!(email: "sk-out-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Out")
    delete destroy_user_session_path
    sign_in_as(outsider)
    get stops_trip_path(@trip, format: :kml)
    assert_response :redirect
  end
end
