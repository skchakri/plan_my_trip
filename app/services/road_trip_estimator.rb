require "net/http"
require "uri"
require "json"
require "digest"

# Roadtrippers-parity road-trip stats: per-leg distance, drive time, and
# estimated fuel cost between a trip's ordered stops — surfaced as an async
# "Road trip stats" card on trips/show and a per-leg breakdown on the Drive
# Co-Pilot. Only meaningful for own-car trips.
#
# Free APIs only:
#   - Routing: the OSRM demo server (router.project-osrm.org). One call routes
#     the whole waypoint list and returns per-leg distance (m) + duration (s).
#     NOTE: the demo host is best-effort — rate-limited, no SLA, sometimes down.
#     That's acceptable under the free-only constraint: every failure mode is
#     rescued to nil (the lazy frame then renders a friendly empty state) and
#     results are cached 14 days so we never hammer it.
#   - Fuel price: EIA's free gas-price API when EIA_API_KEY is configured,
#     cached 1 day; otherwise a hardcoded national-average fallback, labelled
#     an estimate.
#
#   RoadTripEstimator.call(trip, viewer: current_user)
#   # => Result(legs:, total_miles:, total_drive_seconds:, total_fuel_cost:, …)
#   #    or nil when the trip isn't own-car / has < 2 geocoded stops / routing fails.
class RoadTripEstimator
  OSRM_ENDPOINT = "https://router.project-osrm.org/route/v1/driving".freeze
  EIA_ENDPOINT  = "https://api.eia.gov/v2/petroleum/pri/gnd/data".freeze
  EIA_SETTING   = "EIA_API_KEY".freeze

  DEFAULT_PRICE_PER_GALLON = 3.40 # U.S. national average, regular — fallback only.
  DEFAULT_MPG              = 25.0 # Reasonable mixed-driving default when unset.
  MAX_WAYPOINTS            = 25   # OSRM demo limit + keeps the URL sane.

  ROUTE_CACHE_TTL = 14.days
  PRICE_CACHE_TTL = 1.day
  CACHE_PREFIX    = "road_trip_estimator/v1".freeze

  METERS_PER_MILE = 1609.344

  Leg = Struct.new(:from, :to, :miles, :drive_seconds, :fuel_cost, keyword_init: true)

  Result = Struct.new(
    :legs, :total_miles, :total_drive_seconds, :total_fuel_cost,
    :mpg, :mpg_estimated, :price_per_gallon, :price_source, :partial,
    keyword_init: true
  )

  PriceQuote = Struct.new(:value, :source, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def initialize(trip, viewer: nil)
    @trip = trip
    @viewer = viewer
    @partial = false
  end

  def call
    return nil unless @trip&.own_car?

    points = waypoints
    return nil if points.size < 2

    legs_data = osrm_legs(points.map { |p| p[:coord] })
    return nil if legs_data.blank? || legs_data.size != points.size - 1

    price = gas_price
    mpg   = effective_mpg

    legs = []
    total_miles = 0.0
    total_seconds = 0
    legs_data.each_with_index do |leg, i|
      miles = meters_to_miles(leg["distance"].to_f)
      seconds = leg["duration"].to_f.round
      total_miles += miles
      total_seconds += seconds
      legs << Leg.new(
        from: points[i][:name],
        to: points[i + 1][:name],
        miles: miles,
        drive_seconds: seconds,
        fuel_cost: (miles / mpg) * price.value
      )
    end

    Result.new(
      legs: legs,
      total_miles: total_miles,
      total_drive_seconds: total_seconds,
      total_fuel_cost: (total_miles / mpg) * price.value,
      mpg: mpg,
      mpg_estimated: @trip.vehicle_mpg.blank?,
      price_per_gallon: price.value,
      price_source: price.source,
      partial: @partial
    )
  rescue StandardError => e
    Rails.logger.warn("[RoadTripEstimator] trip=#{@trip&.id}: #{e.class}: #{e.message}")
    nil
  end

  private

  # Ordered { name:, lat:, lng:, coord: "lng,lat" } waypoints: the trip origin
  # (geocoded, best-effort) followed by each geocoded itinerary stop in day →
  # activity order. Consecutive duplicate coordinates are collapsed, and the
  # list is capped at MAX_WAYPOINTS (first + last kept, the middle evenly
  # sampled) with #partial flagged so the UI can say "approximate".
  def waypoints
    points = []
    if (origin = origin_waypoint)
      points << origin
    end

    @trip.trip_days.ordered.each do |day|
      day.activities.each do |a|
        next if a.latitude.blank? || a.longitude.blank?
        points << waypoint(a.location_name.presence || a.title, a.latitude, a.longitude)
      end
    end

    points = dedupe_consecutive(points)
    cap_waypoints(points)
  end

  # The trip's home base, geocoded once (cached 90d by Places::Geocoder, which
  # self-rescues to nil). Biased toward the trip's anchor/first stop so a short
  # origin like "SLC" resolves regionally. Skipped silently if there's no
  # origin or it can't be resolved — the route then starts at the first stop.
  def origin_waypoint
    name = @trip.origin.to_s.strip
    return nil if name.blank?

    near_lat = @trip.anchor_lat&.to_f
    near_lng = @trip.anchor_lng&.to_f
    hit = Places::Geocoder.call(name, near_lat: near_lat, near_lng: near_lng)
    return nil unless hit

    waypoint(name, hit.lat, hit.lng)
  end

  def waypoint(name, lat, lng)
    lat = lat.to_f
    lng = lng.to_f
    { name: name.to_s.presence || "Stop", lat: lat, lng: lng, coord: "#{lng},#{lat}" }
  end

  # Drop a waypoint that sits on the same rounded coordinate as the one before
  # it (back-to-back activities at one place add a zero-distance leg otherwise).
  def dedupe_consecutive(points)
    points.each_with_object([]) do |p, acc|
      prev = acc.last
      next acc << p if prev.nil?
      same = prev[:lat].round(4) == p[:lat].round(4) && prev[:lng].round(4) == p[:lng].round(4)
      acc << p unless same
    end
  end

  # Keep the first and last waypoints (the trip's true endpoints) and evenly
  # sample the middle down to MAX_WAYPOINTS. Sets @partial so the card can note
  # the figures are approximate.
  def cap_waypoints(points)
    return points if points.size <= MAX_WAYPOINTS

    @partial = true
    first = points.first
    last = points.last
    middle = points[1..-2]
    keep = MAX_WAYPOINTS - 2
    step = middle.size.to_f / keep
    sampled = (0...keep).map { |i| middle[(i * step).floor] }.uniq
    [ first, *sampled, last ]
  end

  # One OSRM call for the whole route → array of per-leg hashes
  # ({ "distance" => meters, "duration" => seconds }), or nil on any failure.
  # Cached by a signature of the rounded coordinates so an unchanged itinerary
  # never re-hits the demo server.
  def osrm_legs(coords)
    Rails.cache.fetch(route_cache_key(coords), expires_in: ROUTE_CACHE_TTL) do
      fetch_osrm(coords) || :miss
    end.then { |v| v == :miss ? nil : v }
  end

  def fetch_osrm(coords)
    uri = URI("#{OSRM_ENDPOINT}/#{coords.join(';')}")
    uri.query = URI.encode_www_form(overview: "false", annotations: "false")

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 8) do |http|
      http.get(uri.request_uri, "Accept" => "application/json")
    end
    return nil unless res.is_a?(Net::HTTPSuccess)

    json = JSON.parse(res.body)
    return nil unless json["code"] == "Ok"
    legs = json.dig("routes", 0, "legs")
    return nil unless legs.is_a?(Array) && legs.any?

    legs.map { |l| { "distance" => l["distance"], "duration" => l["duration"] } }
  rescue StandardError => e
    Rails.logger.warn("[RoadTripEstimator/osrm] #{e.class}: #{e.message}")
    nil
  end

  # Current U.S. regular gas price. EIA when a key is set (cached 1 day); else
  # the hardcoded fallback, flagged as an estimate so the UI can say so.
  def gas_price
    key = AppSetting.get(EIA_SETTING).presence
    return estimate_price if key.blank?

    cached = Rails.cache.fetch("#{CACHE_PREFIX}/gas_price", expires_in: PRICE_CACHE_TTL) do
      fetch_eia_price(key) || :miss
    end
    cached.is_a?(Numeric) ? PriceQuote.new(value: cached, source: "eia") : estimate_price
  rescue StandardError => e
    Rails.logger.warn("[RoadTripEstimator/eia] #{e.class}: #{e.message}")
    estimate_price
  end

  def estimate_price
    PriceQuote.new(value: DEFAULT_PRICE_PER_GALLON, source: "estimate")
  end

  # EIA v2 — weekly U.S. (PADD: NUS) regular all-formulations retail price.
  # Returns dollars/gallon (Float) or nil.
  def fetch_eia_price(key)
    uri = URI(EIA_ENDPOINT)
    uri.query = URI.encode_www_form(
      "api_key" => key,
      "frequency" => "weekly",
      "data[0]" => "value",
      "facets[product][]" => "EPMR",
      "facets[duoarea][]" => "NUS",
      "sort[0][column]" => "period",
      "sort[0][direction]" => "desc",
      "length" => "1"
    )

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 6) do |http|
      http.get(uri.request_uri, "Accept" => "application/json")
    end
    return nil unless res.is_a?(Net::HTTPSuccess)

    value = JSON.parse(res.body).dig("response", "data", 0, "value")
    price = Float(value) rescue nil
    return nil unless price&.positive?
    price
  end

  def effective_mpg
    v = @trip.vehicle_mpg
    (v.present? && v.to_f.positive?) ? v.to_f : DEFAULT_MPG
  end

  def meters_to_miles(meters)
    meters / METERS_PER_MILE
  end

  def route_cache_key(coords)
    sig = coords.map { |c| c.split(",").map { |n| n.to_f.round(4) }.join(",") }.join(";")
    "#{CACHE_PREFIX}/route/#{Digest::SHA256.hexdigest(sig)}"
  end
end
