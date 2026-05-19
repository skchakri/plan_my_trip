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
  end

  CACHE_TTL = 7.days
  MAX_RESULTS = 24
  PROMPT_SLUG = "nearby_ideas.v1".freeze
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

  def initialize(anchor_label:, lat:, lng:, radius_km: 80, interests: [])
    @anchor_label = anchor_label.to_s.strip
    @lat = lat.is_a?(Numeric) ? lat.to_f : (Float(lat) rescue nil)
    @lng = lng.is_a?(Numeric) ? lng.to_f : (Float(lng) rescue nil)
    @radius_km = [ [ radius_km.to_i, 10 ].max, 400 ].min
    @interests = Array(interests).map { |i| i.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def call
    return [] unless @lat && @lng
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_ideas }
  end

  private

  def cache_key
    digest = Digest::SHA256.hexdigest(
      "#{@anchor_label.downcase}|#{@lat.round(3)},#{@lng.round(3)}|#{@radius_km}|#{@interests.sort.join(',')}"
    )
    "nearby_ideas/v2/#{digest}"
  end

  def fetch_ideas
    catalog = catalog_ideas
    seen = catalog.map { |i| i.name.to_s.downcase }.to_set

    llm = claude_research_ideas
    merged = catalog.dup
    llm.each do |i|
      key = i.name.to_s.downcase
      next if seen.include?(key)
      seen << key
      merged << i
    end

    PlaceRanker.rank!(
      merged.first(MAX_RESULTS),
      interests: @interests,
      anchor_lat: @lat,
      anchor_lng: @lng
    )
  rescue StandardError => e
    Rails.logger.warn("[NearbyIdeas] #{@anchor_label}: #{e.class}: #{e.message}")
    []
  end

  def catalog_ideas
    Place.near(@lat, @lng, radius_m: @radius_km * 1000)
         .where(kind: CATALOG_HIGHLIGHT_KINDS)
         .with_image
         .order(usage_count: :desc, verified: :desc)
         .limit(MAX_RESULTS)
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
        interests: @interests
      }
    )
    items = result.json
    return [] unless items.is_a?(Array)

    items.first(MAX_RESULTS).filter_map do |item|
      name = item["name"].to_s.strip
      next if name.blank?
      lat = item["latitude"]&.to_f
      lng = item["longitude"]&.to_f
      distance_km = (lat && lng) ? haversine_km(@lat, @lng, lat, lng).round(1) : nil

      wiki = enrich_with_wikipedia(name)

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
        longitude: lng
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[NearbyIdeas] claude_research #{@anchor_label}: #{e.class}: #{e.message}")
    []
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

  # Lightweight Wikipedia summary lookup. Returns nil silently — bad
  # network shouldn't break the picker.
  def enrich_with_wikipedia(name)
    title = name.to_s.strip
    return nil if title.blank?
    encoded = URI.encode_www_form_component(title.tr(" ", "_"))
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 4) do |http|
      http.get(uri.request_uri, "User-Agent" => "PlanMyTrip/1.0 (hello@planmytrip.app)")
    end
    return nil unless res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)
    {
      name: json["title"],
      summary: json["extract"],
      image_url: json.dig("thumbnail", "source"),
      wikipedia_url: json.dig("content_urls", "desktop", "page")
    }
  rescue StandardError => _
    nil
  end
end
