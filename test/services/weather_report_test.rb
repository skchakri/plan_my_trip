require "test_helper"

class WeatherReportTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  def row(code: 0, high: 90.0, low: 70.0, precip: nil)
    { "code" => code, "high" => high, "low" => low, "precip" => precip }
  end

  # A report whose network seam (fetch_daily) answers every requested date
  # with `responder.(endpoint, date)` and records each call. Coordinates are
  # stubbed so the geocoder is never touched.
  def stubbed_report(responder, **args)
    wr = WeatherReport.new(destination: "Las Vegas", **args)
    calls = []
    wr.define_singleton_method(:resolve_coords) { [ 36.17, -115.14 ] }
    wr.define_singleton_method(:fetch_daily) do |endpoint, _lat, _lng, from, to, ttl:, precip: false|
      calls << { endpoint: endpoint, from: from, to: to, precip: precip }
      (from..to).each_with_object({}) do |d, rows|
        r = responder.call(endpoint, d)
        rows[d.iso8601] = r if r
      end
    end
    [ wr, calls ]
  end

  ALWAYS_CLEAR = ->(_endpoint, _date) { { "code" => 0, "high" => 90.0, "low" => 70.4, "precip" => 10 } }

  # ── Forecast window ──────────────────────────────────────────────────

  test "trip inside the forecast horizon uses the forecast API for every day" do
    wr, calls = stubbed_report(ALWAYS_CLEAR, start_date: Date.current + 1, end_date: Date.current + 3)
    report = wr.call

    assert_equal [ :forecast ], report.sources
    assert_equal 3, report.days.size
    assert_equal 0, report.truncated_days

    day = report.days.first
    assert_equal Date.current + 1, day.date
    assert_equal 90, day.high_f
    assert_equal 70, day.low_f
    assert_equal "Clear", day.label
    assert_equal "☀️", day.emoji
    assert_equal 10, day.precip_chance

    assert_equal 1, calls.size
    assert_equal WeatherReport::FORECAST_ENDPOINT, calls.first[:endpoint]
    assert calls.first[:precip], "forecast fetch must request precipitation probability"
  end

  # ── Typical (beyond the horizon) ─────────────────────────────────────

  test "far-future trip averages temps and majority-votes conditions across past years" do
    year_data = {
      1 => row(code: 61, high: 90.0, low: 60.0),
      2 => row(code: 61, high: 80.0, low: 50.0),
      3 => row(code: 0,  high: 70.0, low: 40.0)
    }
    year_of = ->(endpoint, date) do
      # Which shifted year is this request for? (date is already shifted back)
      years_back = ((Date.current - date) / 365.0).round
      year_data[years_back.clamp(1, 3)]
    end

    wr, calls = stubbed_report(year_of, start_date: Date.current + 60, end_date: Date.current + 61)
    report = wr.call

    assert_equal [ :typical ], report.sources
    assert_equal 2, report.days.size
    assert_equal WeatherReport::CLIMATE_YEARS, calls.size
    assert calls.all? { |c| c[:endpoint] == WeatherReport::ARCHIVE_ENDPOINT }

    day = report.days.first
    assert_equal 80, day.high_f            # (90 + 80 + 70) / 3
    assert_equal 50, day.low_f             # (60 + 50 + 40) / 3
    assert_equal 61, day.code              # 61 appears 2/3 years
    assert_equal "Light rain", day.label
    assert_nil day.precip_chance, "typical days must not claim a precipitation chance"
  end

  test "trip spanning the horizon mixes forecast and typical days in date order" do
    horizon_last = Date.current + WeatherReport::FORECAST_HORIZON_DAYS - 1
    wr, _calls = stubbed_report(ALWAYS_CLEAR, start_date: horizon_last, end_date: horizon_last + 2)
    report = wr.call

    assert_equal %i[forecast typical], report.days.map(&:source).uniq
    assert_equal :forecast, report.days.first.source
    assert_equal [ :typical ] * 2, report.days.last(2).map(&:source)
    assert_equal report.days.map(&:date), report.days.map(&:date).sort
  end

  # ── Guards + degradation ─────────────────────────────────────────────

  test "returns nil when coordinates cannot be resolved" do
    wr = WeatherReport.new(destination: "Atlantis", start_date: Date.current, end_date: Date.current + 1)
    wr.define_singleton_method(:resolve_coords) { nil }
    assert_nil wr.call
  end

  test "returns nil for invalid or reversed dates" do
    assert_nil WeatherReport.call(destination: "Las Vegas", start_date: "not-a-date", end_date: "2026-08-01")
    assert_nil WeatherReport.call(destination: "Las Vegas", start_date: Date.current + 5, end_date: Date.current + 1)
  end

  test "days the API cannot answer are dropped; an empty answer yields nil" do
    gappy = ->(_e, date) { date == Date.current + 1 ? nil : row }
    wr, = stubbed_report(gappy, start_date: Date.current + 1, end_date: Date.current + 2)
    report = wr.call
    assert_equal [ Date.current + 2 ], report.days.map(&:date)

    dead = ->(_e, _d) { nil }
    wr, = stubbed_report(dead, start_date: Date.current + 1, end_date: Date.current + 2)
    assert_nil wr.call
  end

  test "long trips are capped at MAX_DAYS with the overflow counted" do
    wr, = stubbed_report(ALWAYS_CLEAR, start_date: Date.current + 60, end_date: Date.current + 79)
    report = wr.call
    assert_equal WeatherReport::MAX_DAYS, report.days.size
    assert_equal 4, report.truncated_days
  end

  test "unknown WMO codes fall back to the generic bucket" do
    weird = ->(_e, _d) { row(code: 42) }
    wr, = stubbed_report(weird, start_date: Date.current + 1, end_date: Date.current + 1)
    assert_equal "Mixed conditions", wr.call.days.first.label
  end

  # ── fetch_daily caching (request seam) ───────────────────────────────

  test "fetch_daily caches successful responses but never caches failures" do
    wr = WeatherReport.new(destination: "Las Vegas", start_date: Date.current, end_date: Date.current)
    requests = 0
    answer = { Date.current.iso8601 => row }
    wr.define_singleton_method(:request_daily) do |*_args, **_kw|
      requests += 1
      requests == 1 ? nil : answer
    end

    args = [ WeatherReport::FORECAST_ENDPOINT, 36.17, -115.14, Date.current, Date.current ]
    assert_equal({}, wr.send(:fetch_daily, *args, ttl: 1.hour))
    assert_equal answer, wr.send(:fetch_daily, *args, ttl: 1.hour), "failure must not be cached"
    assert_equal answer, wr.send(:fetch_daily, *args, ttl: 1.hour)
    assert_equal 2, requests, "success must be served from cache"
  end
end
