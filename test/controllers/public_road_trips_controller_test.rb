require "test_helper"

class PublicRoadTripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @rt = RoadTrip.create!(
      origin: "San Francisco", destination: "Las Vegas", title: "SF to Vegas Road Trip",
      tagline: "570 miles of desert.", status: "published", destination_lat: 36.17, destination_lng: -115.14,
      suggested_days: 3,
      stops: [ { "name" => "Barstow", "blurb" => "Route 66 town", "tag" => "Route 66" } ],
      itinerary: [ { "day" => 1, "title" => "Head out", "summary" => "Drive." } ],
      faqs: [ { "q" => "How long?", "a" => "About 9 hours." } ]
    )
  end

  test "index is public and lists published routes" do
    get road_trips_path
    assert_response :success
    assert_includes response.body, "SF to Vegas Road Trip"
  end

  test "show is public and renders content + JSON-LD" do
    get road_trip_path(@rt.slug)
    assert_response :success
    assert_includes response.body, "SF to Vegas Road Trip"
    assert_includes response.body, "Barstow"
    assert_includes response.body, "TouristTrip"
    assert_includes response.body, "FAQPage"
    # CTA deep-links into the wizard pre-filled.
    assert_includes response.body, "origin=San+Francisco"
  end

  test "a draft route is not publicly visible" do
    draft = RoadTrip.create!(origin: "X", destination: "Y", title: "Secret", status: "draft")
    get road_trip_path(draft.slug)
    assert_response :not_found
  end

  test "unknown slug 404s" do
    get road_trip_path("nope-not-real")
    assert_response :not_found
  end

  test "sitemap lists published routes only" do
    draft = RoadTrip.create!(origin: "X", destination: "Y", title: "Draft", status: "draft")
    get road_trips_sitemap_path(format: :xml)
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, road_trip_url(@rt.slug)
    refute_includes response.body, road_trip_url(draft.slug)
  end

  test "weather frame renders the partial without hitting the network" do
    with_fake_weather(nil) do
      get road_trip_weather_path(@rt.slug)
    end
    assert_response :success
    assert_includes response.body, %(turbo-frame id="road-trip-weather")
  end

  private

  def with_fake_weather(report)
    WeatherReport.singleton_class.class_eval do
      alias_method :__real_call, :call
      define_method(:call) { |**| report }
    end
    yield
  ensure
    WeatherReport.singleton_class.class_eval do
      alias_method :call, :__real_call
      remove_method :__real_call
    end
  end
end
