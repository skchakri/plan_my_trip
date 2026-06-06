require "net/http"
require "uri"
require "json"

module Places
  # Resolves a free-form place name to real-world coordinates via OpenStreetMap
  # Nominatim (free, no API key). The point is COORDINATE TRUTH: LLMs invent
  # plausible-but-wrong lat/lng, which then poisons drive-time estimates and
  # the distance-weighted ranking ("Donut Falls is 200 km away"). We only trust
  # model coordinates when a real gazetteer agrees — or when geocoding can't
  # resolve the name at all (fall back to the model's guess rather than drop it).
  #
  # Usage policy (https://operations.osmfoundation.org/policies/nominatim/):
  #   - <= 1 request/second  → callers must serialize + we cache aggressively.
  #   - a real User-Agent identifying the app                 → set below.
  # Results are cached 90 days; the same trail name geocodes once per quarter.
  #
  #   Places::Geocoder.call("Donut Falls", near_lat: 40.76, near_lng: -111.89)
  #   # => { lat: 40.63, lng: -111.69, display_name: "Donut Falls, ..." } or nil
  class Geocoder
    ENDPOINT = "https://nominatim.openstreetmap.org/search".freeze
    GOOGLE_ENDPOINT = "https://maps.googleapis.com/maps/api/place/textsearch/json".freeze
    GOOGLE_SETTING = "GOOGLE_PLACES_API_KEY".freeze
    USER_AGENT = "PlanMyTrip/1.0 (hello@planmytrip.app)".freeze
    CACHE_TTL = 90.days
    CACHE_PREFIX = "places/geocoder/v1".freeze
    MIN_QUERY_LENGTH = 3

    Result = Struct.new(:lat, :lng, :display_name, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    # near_lat/near_lng bias the search toward the trip's region via a viewbox
    # so "Memorial Park" near Salt Lake resolves locally, not to the first
    # Memorial Park on Earth. bias_km sizes that viewbox.
    def initialize(query, near_lat: nil, near_lng: nil, bias_km: 200)
      @query = query.to_s.strip
      @near_lat = near_lat.is_a?(Numeric) ? near_lat.to_f : (Float(near_lat) rescue nil)
      @near_lng = near_lng.is_a?(Numeric) ? near_lng.to_f : (Float(near_lng) rescue nil)
      @bias_km = bias_km.to_i.clamp(10, 1000)
    end

    def call
      return nil if @query.length < MIN_QUERY_LENGTH

      cached = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch || :miss }
      return nil if cached == :miss || cached.nil?
      Result.new(**cached.symbolize_keys)
    rescue StandardError => e
      Rails.logger.warn("[Places::Geocoder] #{@query}: #{e.class}: #{e.message}")
      nil
    end

    private

    def cache_key
      box = (@near_lat && @near_lng) ? "#{@near_lat.round(1)},#{@near_lng.round(1)},#{@bias_km}" : "global"
      "#{CACHE_PREFIX}/#{Digest::SHA256.hexdigest("#{@query.downcase}|#{box}")}"
    end

    # Returns a plain Hash (cache-friendly) or nil. Prefers Google Places when
    # a GOOGLE_PLACES_API_KEY is configured (better POI matching + no 1-req/sec
    # cap), and always falls back to free Nominatim. The :miss sentinel is
    # applied by the caller so we also cache negative lookups for a while.
    def fetch
      google_lookup || nominatim_lookup
    end

    # Google Places Text Search — strong at named POIs ("Donut Falls") and
    # biased toward the anchor. No-op (returns nil) unless a key is set.
    def google_lookup
      key = AppSetting.get(GOOGLE_SETTING).presence
      return nil if key.blank?

      params = { query: @query, key: key }
      if @near_lat && @near_lng
        params[:location] = "#{@near_lat},#{@near_lng}"
        params[:radius] = [ @bias_km * 1000, 50_000 ].min # Google caps radius at 50 km
      end
      uri = URI(GOOGLE_ENDPOINT)
      uri.query = URI.encode_www_form(params)

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 6) do |http|
        http.get(uri.request_uri, "Accept" => "application/json")
      end
      return nil unless res.is_a?(Net::HTTPSuccess)

      json = JSON.parse(res.body)
      # Surface quota/key problems in logs but degrade to Nominatim.
      if json["status"].present? && !%w[OK ZERO_RESULTS].include?(json["status"])
        Rails.logger.warn("[Places::Geocoder/google] #{@query}: #{json["status"]} #{json["error_message"]}")
        return nil
      end
      hit = Array(json["results"]).first
      return nil unless hit.is_a?(Hash)
      loc = hit.dig("geometry", "location")
      lat = loc && (Float(loc["lat"]) rescue nil)
      lng = loc && (Float(loc["lng"]) rescue nil)
      return nil unless lat && lng
      name = [ hit["name"], hit["formatted_address"] ].compact.reject(&:blank?).join(", ")
      { "lat" => lat, "lng" => lng, "display_name" => name }
    rescue StandardError => e
      Rails.logger.warn("[Places::Geocoder/google] #{@query}: #{e.class}: #{e.message}")
      nil
    end

    def nominatim_lookup
      params = { q: @query, format: "jsonv2", limit: 1, addressdetails: 0 }
      if @near_lat && @near_lng
        params[:viewbox] = viewbox
        params[:bounded] = 1
      end
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(params)

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 6) do |http|
        http.get(uri.request_uri, "User-Agent" => USER_AGENT, "Accept" => "application/json")
      end
      return nil unless res.is_a?(Net::HTTPSuccess)

      hit = Array(JSON.parse(res.body)).first
      return nil unless hit.is_a?(Hash)
      lat = Float(hit["lat"]) rescue nil
      lng = Float(hit["lon"]) rescue nil
      return nil unless lat && lng
      { "lat" => lat, "lng" => lng, "display_name" => hit["display_name"].to_s }
    end

    # left,top,right,bottom box ~bias_km around the anchor.
    def viewbox
      lat_delta = @bias_km / 111.0
      lng_delta = @bias_km / (111.0 * Math.cos(@near_lat * Math::PI / 180.0).abs.clamp(0.01, 1.0))
      left   = @near_lng - lng_delta
      right  = @near_lng + lng_delta
      top    = @near_lat + lat_delta
      bottom = @near_lat - lat_delta
      "#{left},#{top},#{right},#{bottom}"
    end
  end
end
