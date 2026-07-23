require "test_helper"

# The trip strip used to forecast one place — the trip's `destination` — for
# every day, so an itinerary that spends two days in LA then four in San
# Francisco showed LA's weather for all six. TripWeather forecasts each plan
# day where the plan actually puts you, grouping consecutive days at the same
# place into ONE Open-Meteo call.
class TripWeatherTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "tw-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "TW")
    @trip = @user.owned_trips.create!(
      title: "LA then SF", destination: "Los Angeles, CA",
      start_date: Date.current, end_date: Date.current + 5
    )
    @calls = []
  end

  LA = [ 34.0522, -118.2437 ].freeze
  SF = [ 37.7749, -122.4194 ].freeze

  def add_day(index, place:, coords:)
    day = @trip.trip_days.create!(
      title: "Day #{index + 1}", label: "day-#{index + 1}",
      position: index, date: Date.current + index
    )
    day.activities.create!(
      title: "Stop", location_name: place, position: 0,
      latitude: coords[0], longitude: coords[1]
    )
    day
  end

  # Record every WeatherReport.call and answer with one canned Day per date, so
  # nothing touches Open-Meteo and we can assert on the call *shape*.
  def with_recording_weather
    calls = @calls
    WeatherReport.singleton_class.class_eval do
      alias_method :__real_call, :call
      define_method(:call) do |**kwargs|
        calls << kwargs
        dates = (Date.parse(kwargs[:start_date].to_s)..Date.parse(kwargs[:end_date].to_s)).to_a
        days = dates.map do |d|
          WeatherReport::Day.new(date: d, code: 0, label: "Clear", emoji: "☀️",
                                 high_f: 70, low_f: 55, precip_chance: 0, source: :forecast)
        end
        WeatherReport::Report.new(days: days, sources: [ :forecast ], truncated_days: 0)
      end
    end
    yield
  ensure
    WeatherReport.singleton_class.class_eval do
      alias_method :call, :__real_call
      remove_method :__real_call
    end
  end

  test "each day is forecast at that day's own location" do
    2.times { |i| add_day(i, place: "Los Angeles", coords: LA) }
    (2..5).each { |i| add_day(i, place: "San Francisco", coords: SF) }

    report = with_recording_weather { TripWeather.call(@trip) }

    assert_equal 6, report.days.size
    assert_equal [ "Los Angeles" ] * 2 + [ "San Francisco" ] * 4, report.days.map(&:place)
    assert_equal [ "Los Angeles", "San Francisco" ], report.places
  end

  test "consecutive days at one place share a single API call" do
    2.times { |i| add_day(i, place: "Los Angeles", coords: LA) }
    (2..5).each { |i| add_day(i, place: "San Francisco", coords: SF) }

    with_recording_weather { TripWeather.call(@trip) }

    assert_equal 2, @calls.size, "one call per stay, not per day"
    assert_equal [ LA[0], SF[0] ], @calls.map { |c| c[:lat] }
    assert_equal [ Date.current, Date.current + 2 ], @calls.map { |c| c[:start_date] }
    assert_equal [ Date.current + 1, Date.current + 5 ], @calls.map { |c| c[:end_date] }
  end

  test "returning to an earlier city starts a new stay" do
    add_day(0, place: "Los Angeles", coords: LA)
    add_day(1, place: "San Francisco", coords: SF)
    add_day(2, place: "Los Angeles", coords: LA)

    report = with_recording_weather { TripWeather.call(@trip) }

    assert_equal 3, @calls.size
    assert_equal [ "Los Angeles", "San Francisco", "Los Angeles" ], report.days.map(&:place)
    assert_equal [ "Los Angeles", "San Francisco" ], report.places, "places are deduped for the caption"
  end

  test "stops within the same city do not split the stay" do
    add_day(0, place: "Griffith Observatory", coords: [ 34.1184, -118.3004 ])
    add_day(1, place: "Griffith Observatory", coords: [ 34.1185, -118.3005 ])

    with_recording_weather { TripWeather.call(@trip) }

    assert_equal 1, @calls.size, "coords rounded to ~1km before grouping"
  end

  test "a trip with no structured days falls back to one destination forecast" do
    report = with_recording_weather { TripWeather.call(@trip) }

    assert_equal 1, @calls.size
    assert_nil @calls.first[:lat], "no day coords — geocode the destination"
    assert_equal [ "Los Angeles, CA" ], report.places
  end

  test "days with no located activity fall back to the trip destination" do
    @trip.trip_days.create!(title: "Day 1", label: "day-1", position: 0, date: Date.current)
    report = with_recording_weather { TripWeather.call(@trip) }

    assert_equal [ "Los Angeles, CA" ], report.days.map(&:place)
  end

  test "returns nil when the trip has no dates" do
    @trip.update_columns(start_date: nil, end_date: nil)
    assert_nil TripWeather.call(@trip)
  end
end
