require "net/http"
require "uri"
require "json"

# Researches "things to do within a day's drive" of an anchor coordinate.
# Powers the day-trip wizard: given a home base / anchor + a list of user
# interest tags + a drive-time/radius budget, asks Claude (with web search)
# for a ranked mix of trails, drives, family attractions, food stops, etc.
#
# Returns an Array of Idea structs ready to render as picker cards. Cached
# 7 days by SHA256 of (anchor, radius, interests) — shorter than the
# 30-day highlights cache because day-trip relevance shifts with the
# seasons (snowpack, road closures, festival season) and we want users
# to see fresh suggestions when they replan.
#
# Layered like DestinationHighlights:
#
#   1. Catalog hits — Places already in the shared catalog within radius
#   2. Claude research — interest-tuned LLM list with web search for
#      fresh trail conditions / seasonal opens / hidden gems
#   3. Wikipedia enrichment — thumbnails + summary URL when available
#
# Pattern mirrors DestinationHighlights so future work can collapse the
# two services behind a shared base class.
class NearbyIdeas
  Idea = Struct.new(
    :slug, :name, :summary, :image_url, :wikipedia_url, :category,
    :interest, :tags, :drive_minutes, :distance_km, :latitude, :longitude,
    :place_id, :usage_count,
    :community_rating, :community_rating_count,
    :rank, :score, :tier, :rating, :score_breakdown,
    :best_time, :duration_hours,
    keyword_init: true
  ) do
    def to_h
      {
        slug: slug, name: name, summary: summary,
        image_url: image_url, wikipedia_url: wikipedia_url,
        category: category, interest: interest, tags: Array(tags),
        drive_minutes: drive_minutes, distance_km: distance_km,
        latitude: latitude, longitude: longitude,
        place_id: place_id, usage_count: usage_count
      }
    end

    def from_catalog?
      place_id.present?
    end

    def has_real_rating?
      community_rating_count.to_i.positive?
    end

    # A full-day outing rather than a combinable stop: drive time (or, when
    # the model didn't return one, distance in km) crosses LONG_HAUL_MINUTES.
    def long_haul?
      mins = drive_minutes.presence || distance_km
      mins.present? && mins.to_f >= LONG_HAUL_MINUTES
    end
  end

  # 22h, not 7 days: Pixabay's API terms want image URLs re-requested after
  # 24 hours, and the stock-photo URLs are baked into this cached result. A
  # daily rebuild is cheap anyway — the inner AI (7d), wiki/image (30d), and
  # geocode (90d) caches all still hit, so it's a re-rank plus at most a
  # couple of stock re-fetches.
  CACHE_TTL = 22.hours
  # Working-set size for catalog/LLM merge + dedup...
  MAX_RESULTS = 24
  # ...but only this many survive to the picker. Showing a curated set beats
  # padding to MAX_RESULTS with low-scored filler (the long duplicate tail).
  DISPLAY_LIMIT = 12
  PROMPT_SLUG = "nearby_ideas.v1".freeze
  # LLMs invent coordinates. We only spend a geocode lookup when a pick's
  # model coords are missing or land implausibly far outside the radius
  # (the cases that actually corrupt drive-time + distance ranking). Capped
  # per call so a cold cache can't hammer Nominatim's 1-req/sec policy.
  GEOCODE_BUDGET = 8
  GEOCODE_OUT_OF_RANGE_FACTOR = 1.3
  # Two ideas within this many km are treated as the same place (one sight's
  # trailhead / viewpoint / parking all collapse to a single card).
  CLUSTER_RADIUS_KM = 2.0
  # Generic tokens ignored when comparing names for the subsumption check,
  # so "Spiral Jetty" still matches "Spiral Jetty Viewing Area".
  DEDUP_STOPWORDS = %w[the a an of at on in and to].freeze
  # One-way minutes (or km, as a fallback) at/above which a pick is a
  # "full day" outing, not a combinable day-trip stop. Surfaced as a card
  # badge so users don't pair a 3-hour drive with a local hike.
  LONG_HAUL_MINUTES = 90
  CATALOG_HIGHLIGHT_KINDS = %w[
    trail viewpoint landmark natural geological historic
    museum park beach overlook
  ].freeze
  # Same kind→vibe map DestinationHighlights uses so day-trip cards
  # render with the same color/icon vocabulary.
  KIND_TO_CATEGORY = {
    "trail" => "adventure", "viewpoint" => "scenic", "landmark" => "history",
    "natural" => "nature", "geological" => "nature", "historic" => "history",
    "museum" => "cultural", "park" => "nature", "beach" => "relaxing",
    "overlook" => "scenic"
  }.freeze

  def self.call(...)
    new(...).call
  end

  def initialize(anchor_label:, lat:, lng:, radius_km: 80, interests: [], user_query: nil, trip_date: nil)
    @anchor_label = anchor_label.to_s.strip
    @lat = lat.is_a?(Numeric) ? lat.to_f : (Float(lat) rescue nil)
    @lng = lng.is_a?(Numeric) ? lng.to_f : (Float(lng) rescue nil)
    @radius_km = [ [ radius_km.to_i, 10 ].max, 400 ].min
    @interests = Array(interests).map { |i| i.to_s.strip.downcase }.reject(&:blank?).uniq
    @user_query = user_query.to_s.strip
    @trip_date = trip_date.to_s.strip
    @geocode_budget = GEOCODE_BUDGET
  end

  def call
    return [] unless @lat && @lng
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_ideas }
  end

  private

  def cache_key
    digest = Digest::SHA256.hexdigest(
      [
        @anchor_label.downcase,
        "#{@lat.round(3)},#{@lng.round(3)}",
        @radius_km,
        @interests.sort.join(","),
        @user_query.downcase,
        @trip_date
      ].join("|")
    )
    # v3: prompt gained coverage-floor + user_query support.
    # v4: fill_missing_images backfills photos via PlaceImageLookup.
    # v5: stock-photo (Pixabay) last tier for ideas Wikipedia/Commons can't
    # illustrate; v6: dedupe casualties also fall back to stock. v7: drop
    # non-free media (logos/cover art) + opensearch relevance guard in the
    # image lookup, so collisions like the Kenny Rogers cover for "Donut
    # Falls" re-resolve. v8: true-distance radius filter, same-place dedup
    # (proximity + name), long-haul down-rank, and the curated display cap —
    # roll out immediately instead of waiting out the 22h TTL. Bumps re-enrich
    # cheaply — the inner AI + image caches still hit.
    "nearby_ideas/v8/#{digest}"
  end

  def fetch_ideas
    merged = merge_catalog_and_llm
    # Rank first so proximity/name dedup can keep the *best-scored* member of
    # each cluster; then cap, fill images for survivors only, and re-rank so
    # rank/tier numbering is correct on the final, deduped set.
    ranked = PlaceRanker.rank!(merged, interests: @interests, anchor_lat: @lat, anchor_lng: @lng)
    unique = dedupe_same_place(ranked).first(DISPLAY_LIMIT)
    fill_missing_images(unique)
    PlaceRanker.rank!(unique, interests: @interests, anchor_lat: @lat, anchor_lng: @lng)
  rescue StandardError => e
    Rails.logger.warn("[NearbyIdeas] #{@anchor_label}: #{e.class}: #{e.message}")
    []
  end

  # Catalog hits + LLM research, with the cheap exact-name dedup that keeps an
  # LLM idea from shadowing a catalog row of the same name. Proximity/name
  # clustering (dedupe_same_place) runs later, after ranking.
  def merge_catalog_and_llm
    catalog = catalog_ideas
    seen = catalog.map { |i| i.name.to_s.downcase }.to_set
    merged = catalog.dup
    claude_research_ideas.each do |i|
      key = i.name.to_s.downcase
      next if seen.include?(key)
      seen << key
      merged << i
    end
    merged
  end

  # Collapse ideas that point at the same real place. Input is assumed
  # best-first (ranked), so the first member of each cluster — the highest
  # scored — is the one kept. Two ideas cluster when they sit within
  # CLUSTER_RADIUS_KM of each other (different access points of one sight)
  # OR one name's significant-word set subsumes the other's ("Great Salt
  # Lake" vs "Great Salt Lake State Park"; "Spiral Jetty" vs "Pink Lake at
  # Spiral Jetty") — the duplication the exact-name pass can't catch.
  def dedupe_same_place(ideas)
    kept = []
    ideas.each do |cand|
      kept << cand unless kept.any? { |k| same_place?(cand, k) }
    end
    kept
  end

  def same_place?(a, b)
    return true if name_subsumes?(a.name, b.name)
    return false unless a.latitude && a.longitude && b.latitude && b.longitude

    haversine_km(a.latitude.to_f, a.longitude.to_f, b.latitude.to_f, b.longitude.to_f) <= CLUSTER_RADIUS_KM
  end

  # True when the shorter name's significant words are all contained in the
  # longer's. Requires ≥2 shared significant words so a single generic token
  # ("Lake", "Falls") can't vacuum up unrelated places.
  def name_subsumes?(x, y)
    wx = dedup_tokens(x)
    wy = dedup_tokens(y)
    smaller, larger = wx.size <= wy.size ? [ wx, wy ] : [ wy, wx ]
    return false if smaller.size < 2

    smaller.subset?(larger)
  end

  def dedup_tokens(name)
    name.to_s.downcase.scan(/[a-z0-9]+/)
        .reject { |t| t.length < 2 || DEDUP_STOPWORDS.include?(t) }
        .to_set
  end

  def catalog_ideas
    # `Place.near` is bounding-box only, so its square reaches ~1.41× the
    # radius at the corners. Re-filter by true great-circle distance so a
    # "within 50 mi" request never surfaces a 63-mi pick. Pull a generous
    # candidate window first (still popularity-ordered) before the Ruby
    # distance cut + final cap.
    Place.near(@lat, @lng, radius_m: @radius_km * 1000)
         .where(kind: CATALOG_HIGHLIGHT_KINDS)
         .with_image
         .order(usage_count: :desc, verified: :desc)
         .limit(MAX_RESULTS * 4)
         .select { |p| haversine_km(@lat, @lng, p.latitude.to_f, p.longitude.to_f) <= @radius_km }
         .first(MAX_RESULTS)
         .map { |p| place_to_idea(p) }
  rescue StandardError => e
    Rails.logger.warn("[NearbyIdeas] catalog #{@anchor_label}: #{e.class}: #{e.message}")
    []
  end

  def place_to_idea(place)
    distance_km = haversine_km(@lat, @lng, place.latitude.to_f, place.longitude.to_f).round(1)
    Idea.new(
      slug: "place-#{place.id}",
      name: place.name,
      summary: place.description.presence || place.famous_for.presence,
      image_url: place.image_url,
      wikipedia_url: place.source_urls.is_a?(Hash) ? place.source_urls["wikipedia"] : nil,
      category: KIND_TO_CATEGORY[place.kind] || "scenic",
      interest: nil,
      tags: [ "from_catalog", ("crowd_favorite" if place.usage_count.to_i >= 3) ].compact,
      drive_minutes: estimate_drive_minutes(distance_km),
      distance_km: distance_km,
      latitude: place.latitude.to_f,
      longitude: place.longitude.to_f,
      place_id: place.id,
      usage_count: place.usage_count,
      community_rating: place.community_rating,
      community_rating_count: place.community_rating_count.to_i
    )
  end

  def claude_research_ideas
    result = Ai::Caller.call(
      slug: PROMPT_SLUG,
      variables: {
        anchor: @anchor_label.presence || "#{@lat.round(3)}, #{@lng.round(3)}",
        anchor_lat: @lat,
        anchor_lng: @lng,
        radius_km: @radius_km,
        interests: @interests,
        user_query: @user_query,
        trip_date: @trip_date
      }
    )
    items = result.json
    return [] unless items.is_a?(Array)

    items = items.first(MAX_RESULTS)
    # Wikipedia summaries used to be fetched serially inside the loop — one
    # HTTP round-trip per idea (~20s for a 24-idea list). Prefetch them
    # concurrently; each lookup is independently cached.
    wiki_by_name = prefetch_wikipedia(items.map { |i| i["name"].to_s.strip })

    items.filter_map do |item|
      name = item["name"].to_s.strip
      next if name.blank?
      lat, lng, distance_km = verified_coords(name, item["latitude"]&.to_f, item["longitude"]&.to_f)

      wiki = wiki_by_name[name]

      Idea.new(
        slug: slugify(name),
        name: wiki&.dig(:name) || name,
        summary: (wiki&.dig(:summary).presence || item["summary"].to_s.strip),
        image_url: wiki&.dig(:image_url) || item["image_url"],
        wikipedia_url: wiki&.dig(:wikipedia_url),
        category: item["category"].to_s.strip.presence || "scenic",
        interest: item["interest"].to_s.strip.presence,
        tags: Array(item["tags"]).map { |t| t.to_s.strip }.reject(&:blank?),
        drive_minutes: item["drive_minutes"]&.to_i || estimate_drive_minutes(distance_km),
        distance_km: distance_km,
        latitude: lat,
        longitude: lng,
        best_time: item["best_time"].to_s.strip.presence,
        duration_hours: (Float(item["duration_hours"]) rescue nil)
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[NearbyIdeas] claude_research #{@anchor_label}: #{e.class}: #{e.message}")
    []
  end

  # Returns [lat, lng, distance_km], replacing the LLM's coordinates with a
  # geocoded truth when the model's are missing or land implausibly far
  # outside the radius. Geocoding is budgeted + only consulted for the
  # suspect minority, so the common (already-plausible) case stays free.
  def verified_coords(name, lat, lng)
    distance_km = (lat && lng) ? haversine_km(@lat, @lng, lat, lng).round(1) : nil
    suspect = lat.nil? || lng.nil? || distance_km.nil? ||
              distance_km > @radius_km * GEOCODE_OUT_OF_RANGE_FACTOR
    return [ lat, lng, distance_km ] unless suspect && @geocode_budget.positive?

    @geocode_budget -= 1
    # Nominatim's 1 req/sec pacing lives inside Places::Geocoder now, wrapped
    # around the actual network call — cache hits and Google lookups are free.
    geo = lookup_geocode(name)
    return [ lat, lng, distance_km ] if geo.nil?

    geo_distance = haversine_km(@lat, @lng, geo.lat, geo.lng).round(1)
    # Only adopt the geocoded point if it's actually within reach — a name
    # collision resolving to another state is worse than the model's guess.
    if geo_distance <= @radius_km * GEOCODE_OUT_OF_RANGE_FACTOR
      [ geo.lat, geo.lng, geo_distance ]
    else
      [ lat, lng, distance_km ]
    end
  end

  # Seam over the geocoder so tests can inject a fake without hitting the
  # network. Returns a Places::Geocoder::Result or nil.
  def lookup_geocode(name)
    Places::Geocoder.call(name, near_lat: @lat, near_lng: @lng, bias_km: (@radius_km * 1.5).round)
  end

  # Rough estimate: 60 km/h average across mixed road types. Used only as a
  # fallback when the LLM didn't return its own drive_minutes estimate.
  def estimate_drive_minutes(distance_km)
    return nil if distance_km.nil?
    (distance_km / 60.0 * 60).round
  end

  def haversine_km(lat1, lng1, lat2, lng2)
    Place.haversine_m(lat1, lng1, lat2, lng2) / 1000.0
  end

  def slugify(name)
    name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-+|-+$)/, "")
  end

  WIKI_THREADS = 8
  WIKI_CACHE_TTL = 30.days

  # Most LLM ideas (trailheads, local waterfalls) have no exact-title Wikipedia
  # page, so the title-based enrichment leaves them photo-less. Backfill via
  # PlaceImageLookup, whose geosearch tiers (Wikipedia ≤1km, Commons geo-tagged
  # photos ≤2km) work off the idea's *verified* coordinates. Concurrent +
  # 30-day cached inside the lookup; runs once per anchor thanks to the
  # result cache around fetch_ideas.
  def fill_missing_images(ideas)
    missing = ideas.select { |i| i.image_url.blank? && i.name.present? }
    return ideas if missing.empty?

    missing.each_slice(WIKI_THREADS) do |batch|
      batch.map do |idea|
        Thread.new do
          idea.image_url = PlaceImageLookup.call(idea.name, lat: idea.latitude, lng: idea.longitude) ||
                           stock_photo_for(idea)
        rescue StandardError => e
          Rails.logger.warn("[NearbyIdeas] image fill #{idea.name}: #{e.class}: #{e.message}")
        end
      end.each(&:join)
    end

    # Nearby ideas can geosearch onto the same Commons photo — a grid of
    # repeated images reads as broken, so only the first keeps it; later
    # claimants get a stock photo instead (or nothing if even that collides).
    taken = Set.new
    ideas.each do |idea|
      next if idea.image_url.blank?
      next if taken.add?(idea.image_url)
      idea.image_url = stock_photo_for(idea)
      idea.image_url = nil if idea.image_url.present? && !taken.add?(idea.image_url)
    end
    ideas
  end

  # Last-tier photo source when Wikipedia/Commons have nothing: stock search.
  # Pixabay only — its 1 req/sec budget (5k/hr) is the lone stock API safe for
  # the live path (Pexels/Unsplash throttle at 19s/75s between calls; they
  # stay reserved for batch seeding via LandmarkImageFinder defaults). Tries
  # the actual place name first, then a category keyword for a representative
  # (not place-specific) shot. Each query cached 30 days.
  STOCK_PROVIDERS = %i[pixabay].freeze
  # Descriptive tags first (most specific), then category fallbacks.
  STOCK_KEYWORDS = {
    "waterfall"   => "waterfall canyon",
    "swimming"    => "swimming hole creek",
    "wildlife"    => "wildlife mountains",
    "dark_sky"    => "starry night sky landscape",
    "adventure"   => "hiking adventure mountains",
    "scenic"      => "scenic mountain vista",
    "family"      => "family park outdoors",
    "food"        => "local restaurant food",
    "cultural"    => "historic downtown street",
    "history"     => "historic site monument",
    "nature"      => "forest nature trail",
    "relaxing"    => "peaceful lake morning",
    "photography" => "dramatic landscape",
    "shopping"    => "market street shops",
    "nightlife"   => "city lights evening",
    "event"       => "outdoor festival crowd"
  }.freeze

  def stock_photo_for(idea)
    region = @anchor_label.split(",").last.to_s.strip
    by_name = cached_stock_lookup("name|#{idea.name}|#{region}") do
      LandmarkImageFinder.call(idea.name, state: region, providers: STOCK_PROVIDERS)&.dig(:url)
    end
    return by_name if by_name

    keyword = (Array(idea.tags).map(&:to_s) & STOCK_KEYWORDS.keys).first || idea.category.to_s
    query = STOCK_KEYWORDS[keyword]
    return nil if query.blank?

    cached_stock_lookup("kw|#{query}|#{region}") do
      LandmarkImageFinder.call(query, state: region, providers: STOCK_PROVIDERS)&.dig(:url)
    end
  end

  def cached_stock_lookup(key)
    # Same 22h ceiling as CACHE_TTL — Pixabay URLs are only contractually
    # valid for 24 hours, so don't hand a stale one to a fresh result build.
    cached = Rails.cache.fetch("nearby_ideas/stock/v1/#{Digest::SHA256.hexdigest(key.downcase)}", expires_in: CACHE_TTL) do
      yield || :miss
    end
    cached == :miss ? nil : cached
  end

  # Concurrent, cached Wikipedia prefetch for a batch of idea names.
  # Returns { name => summary_hash_or_nil }. Wikipedia's REST API has no
  # 1-req/sec policy, so a small thread pool is fine; failures degrade to
  # the LLM's own summary per idea.
  def prefetch_wikipedia(names)
    names = names.reject(&:blank?).uniq
    names.each_slice(WIKI_THREADS).flat_map do |batch|
      batch.map { |name| Thread.new { [ name, enrich_with_wikipedia(name) ] } }.map(&:value)
    end.to_h
  rescue StandardError => e
    Rails.logger.warn("[NearbyIdeas] wikipedia prefetch: #{e.class}: #{e.message}")
    {}
  end

  # Lightweight Wikipedia summary lookup, cached — the same landmark name
  # resolves identically for every user/anchor. Returns nil silently — bad
  # network shouldn't break the picker.
  def enrich_with_wikipedia(name)
    title = name.to_s.strip
    return nil if title.blank?
    # v2: image_url now filtered to free media — re-fetch so cached covers/logos
    # (e.g. a song cover for a place-name collision) get dropped.
    cached = Rails.cache.fetch("nearby_ideas/wiki/v2/#{Digest::SHA256.hexdigest(title.downcase)}", expires_in: WIKI_CACHE_TTL) do
      fetch_wikipedia_summary(title) || :miss
    end
    cached == :miss ? nil : cached
  end

  def fetch_wikipedia_summary(title)
    encoded = URI.encode_www_form_component(title.tr(" ", "_"))
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 4) do |http|
      http.get(uri.request_uri, "User-Agent" => "Wanderply/1.0 (hello@wanderply.com)")
    end
    return nil unless res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)
    thumb = json.dig("thumbnail", "source")
    {
      name: json["title"],
      summary: json["extract"],
      # Drop non-free media (a song/film/brand whose name collides with a place
      # returns its cover/logo, not a photo) so the card falls through to the
      # coordinate-anchored image tiers in fill_missing_images.
      image_url: (thumb if PlaceImageLookup.usable_photo_url?(thumb)),
      wikipedia_url: json.dig("content_urls", "desktop", "page")
    }
  rescue StandardError => _
    nil
  end
end
