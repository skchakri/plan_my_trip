require "net/http"
require "uri"
require "json"

# Builds the list of drive-by narration landmarks for a trip — the points
# the Drive Co-Pilot speaks about when the user is near them but which
# AREN'T scheduled itinerary stops (historic markers, scenic overlooks,
# ghost towns, geological features along the road).
#
# Persists results as RouteLandmark rows on the trip when given a `trip:`,
# otherwise returns an Array of plain Hashes for callers that want to
# inspect/sanitize without persisting.
class RouteLandmarksBuilder
  ALLOWED_KINDS = RouteLandmark::KINDS

  def self.call(...)
    new(...).call
  end

  def initialize(destination:, origin: nil, transport_mode: nil, itinerary_stops: [], trip: nil)
    @destination = destination.to_s.strip
    @origin = origin.to_s.strip
    @transport_mode = transport_mode.to_s.strip
    @itinerary_stops = Array(itinerary_stops).map do |s|
      { name: s[:name].to_s.strip, lat: s[:lat], lng: s[:lng] }
    end.reject { |s| s[:name].blank? }
    @trip = trip
  end

  def call
    return persist([]) if @destination.blank?

    result = Ai::Caller.call(
      slug: "route_landmarks.v1",
      variables: {
        origin: @origin,
        destination: @destination,
        transport_mode: @transport_mode,
        itinerary_stops: @itinerary_stops
      }
    )
    items = result.json
    return persist([]) unless items.is_a?(Array)

    sanitized = items.filter_map { |raw| sanitize(raw) }
    enrich_images!(sanitized)
    persist(sanitized)
  rescue StandardError => e
    Rails.logger.warn("[RouteLandmarksBuilder] #{@destination}: #{e.class}: #{e.message}")
    persist([])
  end

  # Persist sanitized hashes onto @trip as RouteLandmark rows. No-op when
  # called without a trip — returns the hash array so callers can inspect
  # the AI output directly (e.g., from a console or test).
  def persist(sanitized)
    return sanitized if @trip.nil?

    @trip.route_landmarks.discard_all if @trip.route_landmarks.respond_to?(:discard_all)
    sanitized.each_with_index do |h, idx|
      @trip.route_landmarks.create!(
        name: h["name"],
        kind: h["kind"],
        latitude: h["lat"],
        longitude: h["lng"],
        narration: h["narration"],
        image_url: h["image_url"],
        wikipedia_url: h["wikipedia_url"],
        position: idx,
        source: "ai"
      )
    end
    @trip.route_landmarks.reload
  end

  private

  USER_AGENT = "Wanderply/1.0 (https://wanderply.com; mailto:hello@wanderply.com)".freeze

  def sanitize(raw)
    return nil unless raw.is_a?(Hash)
    name = raw["name"].to_s.strip
    narration = raw["narration"].to_s.strip
    lat = Float(raw["lat"]) rescue nil
    lng = Float(raw["lng"]) rescue nil
    kind = raw["kind"].to_s.strip.downcase
    return nil if name.blank? || narration.blank? || lat.nil? || lng.nil?
    return nil unless lat.between?(-90, 90) && lng.between?(-180, 180)

    {
      "name" => name,
      "kind" => (ALLOWED_KINDS.include?(kind) ? kind : "scenic"),
      "lat" => lat,
      "lng" => lng,
      "narration" => narration,
      "image_url" => nil,
      "wikipedia_url" => nil
    }
  end

  # Looks up each landmark on Wikipedia and fills in `image_url` +
  # `wikipedia_url`. Two-step: direct title lookup first (fast path for
  # well-known names like "Cove Fort"), then opensearch fallback (handles
  # descriptive names like "Lehi Historic District" → "Lehi, Utah"). Quiet
  # on misses — the Drive Co-Pilot card shows the kind icon when no image.
  def enrich_images!(landmarks)
    landmarks.each do |l|
      data = wikipedia_summary(l["name"]) || resolve_via_opensearch(l["name"])
      next unless data.is_a?(Hash)
      l["image_url"] = data.dig("thumbnail", "source") || data.dig("originalimage", "source")
      l["wikipedia_url"] = data.dig("content_urls", "desktop", "page")
    end
  end

  def resolve_via_opensearch(query)
    uri = URI("https://en.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "opensearch", search: query, limit: 1, namespace: 0, format: "json"
    )
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = USER_AGENT

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) do |http|
      http.request(req)
    end
    return nil unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    title = body.is_a?(Array) ? body[1]&.first : nil
    return nil if title.blank? || title.casecmp?(query.to_s)  # avoid identical-title retry loop

    wikipedia_summary(title)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn("[RouteLandmarksBuilder] opensearch #{query}: #{e.class}: #{e.message}")
    nil
  end

  def wikipedia_summary(title)
    encoded = URI.encode_www_form_component(title.to_s.tr(" ", "_"))
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = USER_AGENT
    req["Accept"] = "application/json"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) do |http|
      http.request(req)
    end
    return nil unless res.is_a?(Net::HTTPSuccess)

    json = JSON.parse(res.body)
    # Disambiguation pages don't have a single useful image.
    return nil if json["type"] == "disambiguation"
    json
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn("[RouteLandmarksBuilder] wiki #{title}: #{e.class}: #{e.message}")
    nil
  end
end
