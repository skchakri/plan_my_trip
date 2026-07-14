require "test_helper"

# The weather strip loads through two lazy turbo-frame endpoints —
# /trips/:id/weather (trip page) and /trip_wizard/weather (review step).
# Both must render the partial with a stubbed WeatherReport, collapse to an
# empty frame when the report is nil, and never leak across authorization.
class Trips::WeatherFrameTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "wx-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Wex")
    @trip = @user.owned_trips.create!(
      title: "Vegas run", destination: "Las Vegas, NV",
      start_date: Date.current + 3, end_date: Date.current + 5
    )
    sign_in_as(@user)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  # Swap WeatherReport.call for a canned report (nil allowed) — the service
  # otherwise geocodes + hits Open-Meteo, and tests never touch the network.
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

  def sample_report
    day = WeatherReport::Day.new(
      date: Date.current + 3, code: 0, label: "Clear", emoji: "☀️",
      high_f: 91, low_f: 68, precip_chance: 25, source: :forecast
    )
    WeatherReport::Report.new(days: [ day ], sources: [ :forecast ], truncated_days: 0)
  end

  test "trip weather frame renders the per-day strip" do
    with_fake_weather(sample_report) do
      get weather_trip_path(@trip)
    end
    assert_response :success
    assert_includes response.body, %(turbo-frame id="trip-weather")
    assert_includes response.body, "Weather"
    assert_includes response.body, "91°"
    assert_includes response.body, "💧 25%"
    assert_includes response.body, "live forecast"
  end

  test "trip weather frame collapses to an empty frame when the report is nil" do
    with_fake_weather(nil) do
      get weather_trip_path(@trip)
    end
    assert_response :success
    assert_includes response.body, %(turbo-frame id="trip-weather")
    refute_includes response.body, "Weather"
  end

  test "trip weather requires trip access" do
    outsider = User.create!(email: "wx-out-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Out")
    delete destroy_user_session_path # Devise ignores a sign-in while a session is live
    sign_in_as(outsider)
    with_fake_weather(sample_report) do
      get weather_trip_path(@trip)
    end
    assert_response :redirect
  end

  test "wizard weather frame renders from the draft with the wizard frame id" do
    post wizard_destination_path, params: { wizard: {
      destination: "Los Angeles", start_date: (Date.current + 3).to_s, end_date: (Date.current + 5).to_s
    } }
    with_fake_weather(sample_report) do
      get wizard_weather_path
    end
    assert_response :success
    assert_includes response.body, %(turbo-frame id="wizard-weather")
    assert_includes response.body, "91°"
  end
end
