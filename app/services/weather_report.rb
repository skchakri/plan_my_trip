require "net/http"
require "uri"
require "json"
require "digest"

# Per-day weather for a trip's date range, surfaced as an async "Weather"
# strip on trips/show and the wizard review step. Free API only — Open-Meteo
# (open-meteo.com), no key, no signup:
#
#   - Dates within the next 16 days → the live forecast API (high/low,
#     conditions, precipitation chance). Cached 3 hours.
#   - Dates further out → "typical conditions": the archive API's recorded
#     weather for the SAME calendar dates over the past CLIMATE_YEARS years,
#     averaged (temps) / majority-voted (conditions). Honest about being an
#     estimate — the UI labels it "typical", never "forecast". Cached 30 days.
#   - Dates already past → the archive's recorded actuals.
#
# Coordinates come from the caller (the wizard draft already geocoded the
# destination) or fall back to Places::Geocoder (cached 90 days). Every
# failure mode is rescued to nil so the lazy frame simply renders nothing.
#
#   WeatherReport.call(destination: "Las Vegas", start_date: d1, end_date: d2)
#   # => Report(days: [Day, ...], sources: [:forecast, :typical], truncated_days: 0) or nil
class WeatherReport
  FORECAST_ENDPOINT = "https://api.open-meteo.com/v1/forecast".freeze
  ARCHIVE_ENDPOINT  = "https://archive-api.open-meteo.com/v1/archive".freeze

  FORECAST_HORIZON_DAYS = 16      # Open-Meteo's max forecast_days
  MAX_DAYS              = 16      # cap the strip; longer trips get a "+N more" note
  CLIMATE_YEARS         = 3       # years of history behind a "typical" day
  FORECAST_CACHE_TTL    = 3.hours
  HISTORY_CACHE_TTL     = 30.days
  CACHE_PREFIX          = "weather_report/v1".freeze

  Day = Struct.new(:date, :code, :label, :emoji, :high_f, :low_f, :precip_chance, :source, keyword_init: true)
  Report = Struct.new(:days, :sources, :truncated_days, keyword_init: true)

  # WMO weather interpretation codes → [label, emoji]. Unknown codes fall
  # back to the nearest bucket via WMO_FALLBACK ranges.
  WMO = {
    0 => [ "Clear", "☀️" ],
    1 => [ "Mostly clear", "🌤️" ],
    2 => [ "Partly cloudy", "⛅" ],
    3 => [ "Overcast", "☁️" ],
    45 => [ "Fog", "🌫️" ], 48 => [ "Icy fog", "🌫️" ],
    51 => [ "Light drizzle", "🌦️" ], 53 => [ "Drizzle", "🌦️" ], 55 => [ "Heavy drizzle", "🌧️" ],
    56 => [ "Freezing drizzle", "🌧️" ], 57 => [ "Freezing drizzle", "🌧️" ],
    61 => [ "Light rain", "🌦️" ], 63 => [ "Rain", "🌧️" ], 65 => [ "Heavy rain", "🌧️" ],
    66 => [ "Freezing rain", "🌧️" ], 67 => [ "Freezing rain", "🌧️" ],
    71 => [ "Light snow", "🌨️" ], 73 => [ "Snow", "🌨️" ], 75 => [ "Heavy snow", "❄️" ], 77 => [ "Snow grains", "🌨️" ],
    80 => [ "Light showers", "🌦️" ], 81 => [ "Showers", "🌧️" ], 82 => [ "Heavy showers", "⛈️" ],
    85 => [ "Snow showers", "🌨️" ], 86 => [ "Snow showers", "🌨️" ],
    95 => [ "Thunderstorm", "⛈️" ], 96 => [ "Storm + hail", "⛈️" ], 99 => [ "Storm + hail", "⛈️" ]
  }.freeze
  WMO_UNKNOWN = [ "Mixed conditions", "🌥️" ].freeze

  def self.call(...)
    new(...).call
  end

  def initialize(destination:, start_date:, end_date:, lat: nil, lng: nil)
    @destination = destination.to_s.strip
    @start_date = to_date(start_date)
    @end_date = to_date(end_date)
    @lat = to_f_or_nil(lat)
    @lng = to_f_or_nil(lng)
  end

  def call
    return nil unless @start_date && @end_date && @end_date >= @start_date

    dates = (@start_date..[ @start_date + MAX_DAYS - 1, @end_date ].min).to_a
    lat, lng = resolve_coords
    return nil unless lat && lng

    today = Date.current
    horizon_end = today + FORECAST_HORIZON_DAYS - 1
    past   = dates.select { |d| d < today }
    live   = dates.select { |d| d >= today && d <= horizon_end }
    beyond = dates.select { |d| d > horizon_end }

    days = []
    days.concat(forecast_days(lat, lng, live))  if live.any?
    days.concat(recorded_days(lat, lng, past))  if past.any?
    days.concat(typical_days(lat, lng, beyond)) if beyond.any?
    days.sort_by!(&:date)
    return nil if days.empty?

    Report.new(
      days: days,
      sources: days.map(&:source).uniq,
      truncated_days: [ (@end_date - @start_date).to_i + 1 - MAX_DAYS, 0 ].max
    )
  rescue StandardError => e
    Rails.logger.warn("[WeatherReport] #{@destination}: #{e.class}: #{e.message}")
    nil
  end

  private

  def to_date(value)
    return value if value.is_a?(Date)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def to_f_or_nil(value)
    value.is_a?(Numeric) ? value.to_f : (Float(value) rescue nil)
  end

  def resolve_coords
    return [ @lat, @lng ] if @lat && @lng
    return nil if @destination.blank?
    hit = Places::Geocoder.call(@destination)
    hit ? [ hit.lat, hit.lng ] : nil
  end

  # ── Per-source day builders ──────────────────────────────────────────

  def forecast_days(lat, lng, dates)
    rows = fetch_daily(FORECAST_ENDPOINT, lat, lng, dates.min, dates.max,
                       ttl: FORECAST_CACHE_TTL, precip: true)
    build_days(dates, rows, source: :forecast)
  end

  def recorded_days(lat, lng, dates)
    rows = fetch_daily(ARCHIVE_ENDPOINT, lat, lng, dates.min, dates.max,
                       ttl: HISTORY_CACHE_TTL)
    build_days(dates, rows, source: :recorded)
  end

  # "Typical" = same calendar dates across the past CLIMATE_YEARS years:
  # temperatures averaged, condition code majority-voted. Date#<< clamps
  # Feb 29 to Feb 28 in non-leap years, so leap-day trips are safe.
  def typical_days(lat, lng, dates)
    yearly = (1..CLIMATE_YEARS).map do |y|
      fetch_daily(ARCHIVE_ENDPOINT, lat, lng, dates.min << (12 * y), dates.max << (12 * y),
                  ttl: HISTORY_CACHE_TTL)
    end

    dates.filter_map do |date|
      samples = yearly.each_with_index.filter_map do |rows, i|
        row = rows[(date << (12 * (i + 1))).iso8601]
        row if row && row["high"] && row["low"]
      end
      next if samples.empty?

      code = samples.map { |s| s["code"] }.compact.tally.max_by { |_, n| n }&.first
      label, emoji = wmo_lookup(code)
      Day.new(
        date: date, code: code, label: label, emoji: emoji,
        high_f: (samples.sum { |s| s["high"] } / samples.size).round,
        low_f:  (samples.sum { |s| s["low"] } / samples.size).round,
        precip_chance: nil, source: :typical
      )
    end
  end

  def build_days(dates, rows, source:)
    dates.filter_map do |date|
      row = rows[date.iso8601]
      next unless row && row["high"] && row["low"]
      label, emoji = wmo_lookup(row["code"])
      Day.new(
        date: date, code: row["code"], label: label, emoji: emoji,
        high_f: row["high"].round, low_f: row["low"].round,
        precip_chance: row["precip"]&.round, source: source
      )
    end
  end

  def wmo_lookup(code)
    WMO[code.to_i] || WMO_UNKNOWN
  end

  # ── HTTP + cache ─────────────────────────────────────────────────────

  # Returns { "YYYY-MM-DD" => { "code" =>, "high" =>, "low" =>, "precip" => } }.
  # Failures return {} WITHOUT being cached, so a transient Open-Meteo blip
  # doesn't pin an empty strip for 30 days.
  def fetch_daily(endpoint, lat, lng, from, to, ttl:, precip: false)
    key = "#{CACHE_PREFIX}/#{Digest::SHA256.hexdigest([ endpoint, lat.round(2), lng.round(2), from, to, precip ].join("|"))}"
    cached = Rails.cache.read(key)
    return cached if cached.is_a?(Hash)

    rows = request_daily(endpoint, lat, lng, from, to, precip: precip)
    Rails.cache.write(key, rows, expires_in: ttl) if rows.present?
    rows || {}
  end

  def request_daily(endpoint, lat, lng, from, to, precip:)
    daily = %w[weather_code temperature_2m_max temperature_2m_min]
    daily << "precipitation_probability_max" if precip

    uri = URI(endpoint)
    uri.query = URI.encode_www_form(
      latitude: lat, longitude: lng,
      start_date: from.iso8601, end_date: to.iso8601,
      daily: daily.join(","), temperature_unit: "fahrenheit", timezone: "auto"
    )
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 8) do |http|
      http.get(uri.request_uri, "Accept" => "application/json")
    end
    return nil unless res.is_a?(Net::HTTPSuccess)

    d = JSON.parse(res.body)["daily"]
    return nil unless d.is_a?(Hash)

    Array(d["time"]).each_with_index.each_with_object({}) do |(day, i), rows|
      rows[day] = {
        "code" => d.dig("weather_code", i),
        "high" => d.dig("temperature_2m_max", i),
        "low"  => d.dig("temperature_2m_min", i),
        "precip" => precip ? d.dig("precipitation_probability_max", i) : nil
      }
    end
  rescue StandardError => e
    Rails.logger.warn("[WeatherReport] #{endpoint}: #{e.class}: #{e.message}")
    nil
  end
end
