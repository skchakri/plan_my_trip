# Per-day weather that FOLLOWS the itinerary.
#
# The trip-level strip used to forecast one place — the trip's `destination` —
# for every day. On a multi-city trip that's wrong for most of it: two days in
# LA then four in San Francisco showed LA's weather for all six. Each plan day
# is forecast at *its own* location instead (TripDay#weather_anchor, the same
# coordinates the per-day header chips already use).
#
# One Open-Meteo call per *stay*, not per day: consecutive days sharing a
# location are grouped, so LA→SF is two calls, not six. Days with no located
# activity fall back to the trip destination and join that group.
#
#   TripWeather.call(trip)  # => Report(days: [Day+place, ...], sources:, truncated_days:)
#                           #    or nil when there's nothing to show
class TripWeather
  MAX_DAYS = WeatherReport::MAX_DAYS

  # A WeatherReport::Day plus the place it was forecast at.
  Day = Struct.new(:date, :label, :emoji, :high_f, :low_f, :precip_chance, :source, :place,
                   keyword_init: true)
  Report = Struct.new(:days, :sources, :truncated_days, :places, keyword_init: true)

  def self.call(...) = new(...).call

  def initialize(trip)
    @trip = trip
  end

  def call
    return nil if @trip.start_date.blank? || @trip.end_date.blank?

    stays = group_into_stays(dated_days)
    # No structured days yet (hand-written trip, or still building) — fall back
    # to the old single-destination strip so the frame isn't empty.
    return whole_trip_report if stays.empty?

    days = stays.flat_map { |stay| forecast_stay(stay) }.compact.sort_by(&:date)
    return nil if days.empty?

    Report.new(
      days: days,
      sources: days.map(&:source).uniq,
      truncated_days: [ @trip.trip_days.size - MAX_DAYS, 0 ].max,
      places: days.map(&:place).compact.uniq
    )
  rescue StandardError => e
    Rails.logger.warn("[TripWeather] trip=#{@trip.id}: #{e.class}: #{e.message}")
    nil
  end

  private

  # Dated plan days, capped so a 30-day trip doesn't fan out into 30 API calls.
  def dated_days
    @trip.trip_days.ordered.includes(:activities).select(&:date).first(MAX_DAYS)
  end

  # Collapse consecutive days at the same place into one "stay". Coordinates
  # are rounded to ~1km before comparing so two stops in the same city don't
  # split the stay into separate API calls.
  def group_into_stays(days)
    days.each_with_object([]) do |day, stays|
      coords = day.representative_coords
      key = coords ? coords.map { |c| c.round(2) } : :destination
      last = stays.last
      if last && last[:key] == key
        last[:days] << day
      else
        stays << { key: key, coords: coords, place: day.representative_place, days: [ day ] }
      end
    end
  end

  def forecast_stay(stay)
    lat, lng = stay[:coords]
    dates = stay[:days].map(&:date)
    report = WeatherReport.call(
      destination: @trip.destination,
      start_date: dates.min, end_date: dates.max,
      lat: lat, lng: lng
    )
    return [] unless report

    place = stay[:place].presence || @trip.destination.presence
    report.days.map { |d| decorate(d, place) }
  end

  # Trips with no structured days at all: one call at the destination, which is
  # exactly what the strip did before.
  def whole_trip_report
    report = WeatherReport.call(
      destination: @trip.destination,
      start_date: @trip.start_date,
      end_date: @trip.end_date
    )
    return nil unless report

    place = @trip.destination.presence
    Report.new(
      days: report.days.map { |d| decorate(d, place) },
      sources: report.sources,
      truncated_days: report.truncated_days,
      places: [ place ].compact
    )
  end

  def decorate(day, place)
    Day.new(
      date: day.date, label: day.label, emoji: day.emoji,
      high_f: day.high_f, low_f: day.low_f, precip_chance: day.precip_chance,
      source: day.source, place: place
    )
  end
end
