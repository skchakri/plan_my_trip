require "net/http"
require "uri"
require "json"

# Resolves a place name → thumbnail URL. Used as a fallback when an
# Activity doesn't already have a `photo_url` from a selected highlight.
#
# Four-step:
#   1. Direct title lookup against the Wikipedia REST summary endpoint
#      (fast path for well-known names like "Goblin Valley State Park").
#   2. opensearch resolve → summary, for descriptive names like "Beaver UT"
#      that need title disambiguation.
#   3. Geosearch (when lat/lng given) — find the nearest Wikipedia article
#      within 1km that has a thumbnail. Catches things like motels and
#      trailheads that aren't Wikipedia subjects themselves but sit next
#      to a notable place that is.
#   4. Wikimedia Commons geosearch — for niche places (overlooks, OHV roads,
#      roadside attractions) that don't have a Wikipedia article but do
#      have user-uploaded, geo-tagged photos on Commons. Uses a 2km radius
#      because Commons coverage is sparser than Wikipedia's — but limits
#      to actual photo MIME types so we don't surface book scans or maps.
#
# Cached 30 days per normalized (name, lat, lng) tuple. Returns nil on miss.
class PlaceImageLookup
  USER_AGENT = "PlanMyTrip/1.0 (https://planmytrip.app; mailto:hello@planmytrip.app)".freeze
  CACHE_TTL = 30.days
  # Tight radius so we only return photos of the *actual* place, not "the
  # nearest Wikipedia-documented landmark in town". A motel at coords X and
  # a trailhead 4km away should NOT share the same hero image.
  GEOSEARCH_RADIUS_M = 1000
  COMMONS_GEOSEARCH_RADIUS_M = 2000
  COMMONS_THUMB_WIDTH = 800
  COMMONS_RESULT_LIMIT = 10
  PHOTO_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze

  def self.call(name, lat: nil, lng: nil, exclude_urls: [])
    new(name, lat: lat, lng: lng).call(exclude_urls: exclude_urls)
  end

  def initialize(name, lat: nil, lng: nil)
    @name = name.to_s.strip
    @lat = lat.is_a?(Numeric) ? lat.to_f : (Float(lat) rescue nil)
    @lng = lng.is_a?(Numeric) ? lng.to_f : (Float(lng) rescue nil)
  end

  # Returns a single thumbnail URL. The `exclude_urls` set lets the caller
  # tell us which photos are already taken by other activities in the same
  # trip — we'll skip any geosearch candidate whose photo is in that set,
  # walking down the next candidate. Returns nil if nothing unique is left.
  def call(exclude_urls: [])
    return nil if @name.blank? && (@lat.nil? || @lng.nil?)
    exclude = exclude_urls.to_set
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_candidates }
      .reject { |url| exclude.include?(url) }
      .first
  end

  private

  def cache_key
    key = "#{@name.downcase}|#{@lat&.round(3)}|#{@lng&.round(3)}"
    "place_image_lookup/v4/#{Digest::SHA256.hexdigest(key)}"
  end

  # Returns an ordered list of candidate thumbnail URLs: direct title hit
  # first, then opensearch hit, then geosearch hits (within 1km). Caller
  # picks the first non-excluded one.
  def fetch_candidates
    urls = []
    if @name.present?
      add_image_from(wikipedia_summary(@name), urls)
      add_image_from(resolve_via_opensearch(@name), urls)
    end
    if @lat && @lng
      geosearch_summaries.each { |data| add_image_from(data, urls) }
    end
    if @lat && @lng
      commons_geosearch_thumb_urls.each { |url| urls << url }
    end
    urls.uniq.compact
  rescue => e
    Rails.logger.warn("[PlaceImageLookup] #{@name}: #{e.class}: #{e.message}")
    []
  end

  def add_image_from(data, urls)
    return unless data.is_a?(Hash)
    img = data.dig("thumbnail", "source") || data.dig("originalimage", "source")
    urls << img if img.present?
  end

  def geosearch_summaries
    uri = URI("https://en.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query", list: "geosearch",
      gscoord: "#{@lat}|#{@lng}",
      gsradius: GEOSEARCH_RADIUS_M, gslimit: 8, format: "json"
    )
    res = http_get(uri)
    return [] unless res

    body = JSON.parse(res.body)
    members = body.dig("query", "geosearch") || []
    members.filter_map { |m| wikipedia_summary(m["title"]) }
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn("[PlaceImageLookup] geosearch #{@lat},#{@lng}: #{e.class}: #{e.message}")
    []
  end

  def wikipedia_summary(title)
    encoded = URI.encode_www_form_component(title.to_s.tr(" ", "_"))
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
    res = http_get(uri)
    return nil unless res

    json = JSON.parse(res.body)
    return nil if json["type"] == "disambiguation"
    json
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn("[PlaceImageLookup] summary #{title}: #{e.class}: #{e.message}")
    nil
  end

  def resolve_via_opensearch(query)
    uri = URI("https://en.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "opensearch", search: query, limit: 1, namespace: 0, format: "json"
    )
    res = http_get(uri)
    return nil unless res

    body = JSON.parse(res.body)
    title = body.is_a?(Array) ? body[1]&.first : nil
    return nil if title.blank? || title.casecmp?(query.to_s)

    wikipedia_summary(title)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn("[PlaceImageLookup] opensearch #{query}: #{e.class}: #{e.message}")
    nil
  end

  # Wikimedia Commons geosearch — finds geo-tagged photos within
  # COMMONS_GEOSEARCH_RADIUS_M of (lat, lng). Filters to actual photo
  # extensions to avoid book scans, maps, and SVG diagrams that happen
  # to carry coordinates. The geosearch *generator* returns pages with
  # imageinfo inline, so this is a single round trip.
  def commons_geosearch_thumb_urls
    uri = URI("https://commons.wikimedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query",
      generator: "geosearch",
      ggscoord: "#{@lat}|#{@lng}",
      ggsradius: COMMONS_GEOSEARCH_RADIUS_M,
      ggslimit: COMMONS_RESULT_LIMIT,
      ggsnamespace: 6,
      prop: "imageinfo",
      iiprop: "url|mime",
      iiurlwidth: COMMONS_THUMB_WIDTH,
      format: "json"
    )
    res = http_get(uri)
    return [] unless res

    body = JSON.parse(res.body)
    pages = (body.dig("query", "pages") || {}).values
    # Geosearch ordering is preserved via the `index` field; lower = closer.
    pages.sort_by { |p| p["index"] || 999 }.filter_map do |page|
      title = page["title"].to_s
      next unless PHOTO_EXTENSIONS.any? { |ext| title.downcase.end_with?(ext) }

      info = page.dig("imageinfo")&.first
      next unless info

      mime = info["mime"].to_s
      next unless mime.start_with?("image/") && mime != "image/svg+xml"

      info["thumburl"] || info["url"]
    end
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn("[PlaceImageLookup] commons geosearch #{@lat},#{@lng}: #{e.class}: #{e.message}")
    []
  end

  def http_get(uri)
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = USER_AGENT
    req["Accept"] = "application/json"
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 6, open_timeout: 3) do |http|
      http.request(req)
    end
    res.is_a?(Net::HTTPSuccess) ? res : nil
  end
end
