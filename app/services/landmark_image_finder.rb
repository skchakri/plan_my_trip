require "net/http"
require "uri"
require "json"

# Resolves a landmark name → a high-quality hero photo URL from one of
# several free travel-photo APIs. Tries each provider in order until one
# returns a usable image. Falls through to Wikipedia (the existing path)
# when nothing else works.
#
# Configure via env:
#   PEXELS_API_KEY      → https://www.pexels.com/api/  (200 req/hr, 20k/mo)
#   UNSPLASH_ACCESS_KEY → https://unsplash.com/developers (50 req/hr demo)
#   PIXABAY_API_KEY     → https://pixabay.com/api/docs/  (5k/hr)
#
# Usage:
#   LandmarkImageFinder.call("Zion National Park", state: "Utah")
#   => { url: "https://images.pexels.com/...", source: "pexels", attribution: "Photo by ..." }
class LandmarkImageFinder
  USER_AGENT = "Wanderply/1.0 (https://wanderply.com)".freeze
  TIMEOUT = 8

  PROVIDERS = %i[pexels unsplash pixabay].freeze

  # Per-provider published rate limits. We throttle to the steady-state
  # interval so a long batch run never trips them. Pexels and Unsplash
  # quotas are aggressive enough that the script will pause naturally.
  RATE_LIMITS = {
    pexels:   { per_hour: 200,  min_interval: 19.0 },   # 200/hr → 18s, +1s safety
    unsplash: { per_hour: 50,   min_interval: 75.0 },   # 50/hr  → 72s, +3s safety
    pixabay:  { per_hour: 5000, min_interval: 1.0 }
  }.freeze

  @@last_call_at = Hash.new { |h, k| h[k] = 0.0 }
  @@call_counts  = Hash.new(0)
  @@disabled     = {}
  @@mutex        = Mutex.new

  def self.call(name, state: nil, providers: PROVIDERS)
    new(name, state: state, providers: providers).call
  end

  def self.stats
    @@call_counts.transform_keys(&:to_sym).merge(disabled: @@disabled.keys)
  end

  def self.reset_stats!
    @@last_call_at = Hash.new { |h, k| h[k] = 0.0 }
    @@call_counts  = Hash.new(0)
    @@disabled     = {}
  end

  def initialize(name, state: nil, providers: PROVIDERS)
    @name = name.to_s.strip
    @state = state.to_s.strip
    @providers = Array(providers)
  end

  def call
    return nil if @name.blank?

    @providers.each do |provider|
      next if @@disabled[provider]
      result = case provider
      when :pexels   then with_throttle(:pexels)   { pexels }
      when :unsplash then with_throttle(:unsplash) { unsplash }
      when :pixabay  then with_throttle(:pixabay)  { pixabay }
      end
      return result if result
    end
    nil
  end

  private

  # Enforces RATE_LIMITS[provider][:min_interval] seconds between calls
  # against a given provider. Safe across threads.
  def with_throttle(provider)
    limit = RATE_LIMITS[provider]
    return yield unless limit

    @@mutex.synchronize do
      delta = Time.now.to_f - @@last_call_at[provider]
      sleep_for = limit[:min_interval] - delta
      sleep(sleep_for) if sleep_for.positive?
      @@last_call_at[provider] = Time.now.to_f
      @@call_counts[provider] += 1
    end
    yield
  end

  # Disable a provider for the rest of the process when it returns 429
  # — we won't recover within a reasonable script run, and another
  # provider can usually fill the gap.
  def disable!(provider, reason)
    @@disabled[provider] = reason
    Rails.logger.warn("[LandmarkImageFinder] disabling #{provider}: #{reason}")
  end

  def query_terms
    @state.empty? ? [ @name ] : [ "#{@name} #{@state}", @name ]
  end

  # ─── Pexels ────────────────────────────────────────────────────
  # GET https://api.pexels.com/v1/search?query=Zion+National+Park&per_page=1&orientation=landscape
  # Header: Authorization: <api_key>
  def pexels
    key = AppSetting.get("PEXELS_API_KEY").presence
    return nil if key.blank?

    query_terms.each do |q|
      uri = URI("https://api.pexels.com/v1/search")
      uri.query = URI.encode_www_form(query: q, per_page: 1, orientation: "landscape", size: "large")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = key
      req["User-Agent"] = USER_AGENT
      res = http_get(uri, req)
      if res.is_a?(Net::HTTPTooManyRequests)
        disable!(:pexels, "429 rate limit")
        return nil
      end
      next unless res.is_a?(Net::HTTPSuccess)

      photo = JSON.parse(res.body).dig("photos", 0)
      next unless photo

      return {
        url: photo.dig("src", "large2x") || photo.dig("src", "large") || photo.dig("src", "original"),
        source: "pexels",
        attribution: "Photo by #{photo["photographer"]} on Pexels",
        attribution_url: photo["url"]
      }
    end
    nil
  rescue StandardError => e
    Rails.logger.warn("[LandmarkImageFinder/pexels] #{@name}: #{e.class}: #{e.message}")
    nil
  end

  # ─── Unsplash ──────────────────────────────────────────────────
  # GET https://api.unsplash.com/search/photos?query=Zion&per_page=1&orientation=landscape
  # Header: Authorization: Client-ID <access_key>
  def unsplash
    key = AppSetting.get("UNSPLASH_ACCESS_KEY").presence
    return nil if key.blank?

    query_terms.each do |q|
      uri = URI("https://api.unsplash.com/search/photos")
      uri.query = URI.encode_www_form(query: q, per_page: 1, orientation: "landscape", content_filter: "high")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Client-ID #{key}"
      req["Accept-Version"] = "v1"
      req["User-Agent"] = USER_AGENT
      res = http_get(uri, req)
      if res.is_a?(Net::HTTPTooManyRequests) || res.code.to_s == "403"
        disable!(:unsplash, "#{res.code} rate-limited")
        return nil
      end
      next unless res.is_a?(Net::HTTPSuccess)

      photo = JSON.parse(res.body).dig("results", 0)
      next unless photo

      return {
        url: photo.dig("urls", "regular") || photo.dig("urls", "full"),
        source: "unsplash",
        attribution: "Photo by #{photo.dig("user", "name")} on Unsplash",
        attribution_url: photo.dig("links", "html")
      }
    end
    nil
  rescue StandardError => e
    Rails.logger.warn("[LandmarkImageFinder/unsplash] #{@name}: #{e.class}: #{e.message}")
    nil
  end

  # ─── Pixabay ───────────────────────────────────────────────────
  # GET https://pixabay.com/api/?key=<key>&q=Zion&per_page=3&orientation=horizontal&image_type=photo
  def pixabay
    key = AppSetting.get("PIXABAY_API_KEY").presence
    return nil if key.blank?

    query_terms.each do |q|
      uri = URI("https://pixabay.com/api/")
      uri.query = URI.encode_www_form(
        key: key, q: q, per_page: 3, orientation: "horizontal", image_type: "photo", safesearch: "true"
      )
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      res = http_get(uri, req)
      if res.is_a?(Net::HTTPTooManyRequests)
        disable!(:pixabay, "429 rate limit")
        return nil
      end
      next unless res.is_a?(Net::HTTPSuccess)

      photo = JSON.parse(res.body).dig("hits", 0)
      next unless photo

      return {
        url: photo["largeImageURL"] || photo["webformatURL"],
        source: "pixabay",
        attribution: "Photo by #{photo["user"]} on Pixabay",
        attribution_url: photo["pageURL"]
      }
    end
    nil
  rescue StandardError => e
    Rails.logger.warn("[LandmarkImageFinder/pixabay] #{@name}: #{e.class}: #{e.message}")
    nil
  end

  def http_get(uri, req)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: TIMEOUT, open_timeout: 3) do |http|
      http.request(req)
    end
  end
end
