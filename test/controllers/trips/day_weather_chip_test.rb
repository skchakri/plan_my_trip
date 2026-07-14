require "test_helper"

# Each plan-day header lazily loads /trips/:id/day_weather/:day_id — a chip
# with THAT day's weather at the day's own coordinates. Must render from a
# stubbed WeatherReport, receive the day's coords (not the destination's),
# collapse to an empty frame on nil/missing day, and respect authorization.
class Trips::DayWeatherChipTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "dw-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Dew")
    @trip = @user.owned_trips.create!(
      title: "Loop", destination: "Los Angeles, CA",
      start_date: Date.current + 3, end_date: Date.current + 5
    )
    @day = @trip.trip_days.create!(label: "day-1", title: "Vegas day", accent: "gold", date: Date.current + 3, position: 0)
    sign_in_as(@user)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  # Same seam as weather_frame_test — capture kwargs so we can assert the
  # day's coordinates were forwarded.
  def with_fake_weather(report, captured = nil)
    WeatherReport.singleton_class.class_eval do
      alias_method :__real_call, :call
      define_method(:call) { |**kwargs| captured&.push(kwargs); report }
    end
    yield
  ensure
    WeatherReport.singleton_class.class_eval do
      alias_method :call, :__real_call
      remove_method :__real_call
    end
  end

  def sample_report(source: :forecast, precip: 40)
    day = WeatherReport::Day.new(
      date: @day.date, code: 2, label: "Partly cloudy", emoji: "⛅",
      high_f: 95, low_f: 74, precip_chance: precip, source: source
    )
    WeatherReport::Report.new(days: [ day ], sources: [ source ], truncated_days: 0)
  end

  test "renders the chip with high/low and precip inside the day frame" do
    with_fake_weather(sample_report) do
      get day_weather_trip_path(@trip, day_id: @day.id)
    end
    assert_response :success
    assert_includes response.body, %(turbo-frame id="day-weather-#{@day.id}")
    assert_includes response.body, "95°"
    assert_includes response.body, "💧40%"
  end

  test "typical (far-out) days are labelled typical" do
    with_fake_weather(sample_report(source: :typical, precip: nil)) do
      get day_weather_trip_path(@trip, day_id: @day.id)
    end
    assert_includes response.body, "typical"
  end

  test "passes the day's own coordinates to WeatherReport" do
    @day.activities.create!(title: "Check in — LINQ", group_label: "Lodging", latitude: 36.1178, longitude: -115.1710, position: 0)
    captured = []
    with_fake_weather(sample_report, captured) do
      get day_weather_trip_path(@trip, day_id: @day.id)
    end
    assert_equal 1, captured.size
    assert_in_delta 36.1178, captured.first[:lat], 0.0001
    assert_in_delta(-115.1710, captured.first[:lng], 0.0001)
    assert_equal @day.date, captured.first[:start_date]
    assert_equal @day.date, captured.first[:end_date]
  end

  test "collapses to an empty frame when the report is nil" do
    with_fake_weather(nil) do
      get day_weather_trip_path(@trip, day_id: @day.id)
    end
    assert_response :success
    assert_includes response.body, %(turbo-frame id="day-weather-#{@day.id}")
    refute_includes response.body, "°"
  end

  test "unknown day id renders an empty frame, not a 500" do
    with_fake_weather(sample_report) do
      get day_weather_trip_path(@trip, day_id: SecureRandom.uuid)
    end
    assert_response :success
    refute_includes response.body, "95°"
  end

  test "requires trip access" do
    outsider = User.create!(email: "dw-out-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Out")
    delete destroy_user_session_path
    sign_in_as(outsider)
    with_fake_weather(sample_report) do
      get day_weather_trip_path(@trip, day_id: @day.id)
    end
    assert_response :redirect
  end

  test "representative_coords prefers lodging, falls back to the middle located activity" do
    @day.activities.create!(title: "Depart", latitude: 40.76, longitude: -111.89, position: 0)
    @day.activities.create!(title: "Lunch stop", latitude: 37.10, longitude: -113.58, position: 1)
    @day.activities.create!(title: "Scenic overlook", latitude: 36.90, longitude: -114.00, position: 2)
    assert_in_delta 37.10, @day.representative_coords.first, 0.0001

    @day.activities.create!(title: "Check in at hotel", group_label: "Lodging", latitude: 36.1178, longitude: -115.1710, position: 3)
    assert_in_delta 36.1178, @day.reload.representative_coords.first, 0.0001
  end

  test "representative_coords is nil when no activity has coordinates" do
    @day.activities.create!(title: "Flexible day", position: 0)
    assert_nil @day.representative_coords
  end
end
