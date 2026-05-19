require "net/http"
require "uri"
require "json"

# Pulls a list of "must-see" highlights for a destination from public,
# keyless data sources:
#
#   1. Wikivoyage MediaWiki API — fetches the destination's travel-guide page,
#      then extracts the entries from the "See" section. Each entry is a real
#      visitor-vetted attraction with a short blurb.
#   2. Wikipedia REST API — for each extracted name, fetches a thumbnail +
#      a one-sentence summary as a richer description.
#
# Designed to be swapped for Google Places later — the public interface
# (`call` returning an array of Highlight structs) stays stable.
#
# Results cached for 30 days in Rails.cache, keyed by the normalized
# destination string.
class DestinationHighlights
  Highlight = Struct.new(
    :slug, :name, :summary, :image_url, :wikipedia_url, :category, :tags,
    :place_id, :usage_count, :latitude, :longitude,
    :community_rating, :community_rating_count,
    :rank, :score, :tier, :rating, :score_breakdown,
    keyword_init: true
  ) do
    def to_h
      {
        slug: slug, name: name, summary: summary,
        image_url: image_url, wikipedia_url: wikipedia_url,
        category: category, tags: Array(tags),
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

  # Tunable vibes the user can pick on the highlights step. Used to bias the
  # LLM research prompt — and (cosmetically) to label entries the LLM returns.
  VIBES = %w[relaxing adventure shopping nature family cultural food nightlife scenic photography history].freeze

  USER_AGENT = "PlanMyTrip/1.0 (https://planmytrip.app; mailto:hello@planmytrip.app)".freeze
  CACHE_TTL = 30.days
  MAX_RESULTS = 18
  MIN_BEFORE_FALLBACK = 5
  # Allowed tag values must match what the prompt instructs Claude to emit.
  # Any unknown tag is silently dropped to keep the chips list clean.
  ALLOWED_TAGS = %w[
    iconic underrated needs_4wd drone_ok dawn_only sunset_only dark_sky
    crowd_free family_ok kid_friendly photographers_favorite free fee_required
    permit_required seasonal easy_access long_hike scrambly pet_friendly
    wheelchair_accessible swimming wildlife historic_site local_food michelin
    must_book_ahead
  ].freeze
  # Place kinds that make sense as "things to do/see" — the highlights
  # grid is for excitement, not logistics. Lodging/restaurants/cafes
  # are filtered out (they show up later in the day-plan).
  CATALOG_HIGHLIGHT_KINDS = %w[
    trail viewpoint landmark natural geological historic
    museum park beach overlook
  ].freeze
  # Radius in km we'll pull from the catalog when destination coords are
  # known. ~50km is roughly an hour's drive — what people consider "in
  # this trip" for road-trip planning.
  CATALOG_RADIUS_M = 50_000

  def self.call(destination, vibes: [], lat: nil, lng: nil)
    new(destination, vibes: vibes, lat: lat, lng: lng).call
  end

  def initialize(destination, vibes: [], lat: nil, lng: nil)
    @destination = destination.to_s.strip
    @vibes = Array(vibes).map { |v| v.to_s.strip.downcase }.reject(&:blank?) & VIBES
    @lat = lat.is_a?(Numeric) ? lat.to_f : (Float(lat) rescue nil)
    @lng = lng.is_a?(Numeric) ? lng.to_f : (Float(lng) rescue nil)
  end

  def call
    return [] if @destination.blank?
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_highlights }
  end

  private

  def cache_key
    coords = (@lat && @lng) ? "|#{@lat.round(3)},#{@lng.round(3)}" : ""
    digest = Digest::SHA256.hexdigest("#{@destination.downcase}|#{@vibes.sort.join(',')}#{coords}")
    "destination_highlights/v11/#{digest}"
  end

  def fetch_highlights
    # 1. Catalog hits — Places the community has already vetted near this
    #    destination. These lead the list because they carry social proof
    #    (usage_count) and reuse images we've already loaded.
    catalog = catalog_highlights
    seen_names = catalog.map { |h| h.name.to_s.downcase }.to_set

    # 2. Big cities (Paris, Vegas, Tokyo, NYC) delegate to district sub-pages,
    #    so the main Wikivoyage page has few real {{see}} listings. Junk-filter
    #    the WV pull first, then top up from Wikipedia's "Tourist attractions
    #    in X" category if the WV list is thin.
    wv = wikivoyage_see_names.reject { |n| junk_name?(n) }
    names = wv.size >= MIN_BEFORE_FALLBACK ? wv : (wv + wikipedia_category_attractions).reject { |n| junk_name?(n) }
    names = names.uniq.first(MAX_RESULTS)
    open_data = names.map { |n| enrich_with_wikipedia(n) }.compact

    # 3. Claude's curated, vibe-aware list — richer summaries + tags.
    llm = claude_research_highlights

    merged = catalog.dup
    llm.each do |h|
      next if seen_names.include?(h.name.to_s.downcase)
      seen_names << h.name.to_s.downcase
      merged << h
    end
    open_data.each do |h|
      next if seen_names.include?(h.name.to_s.downcase)
      seen_names << h.name.to_s.downcase
      merged << h
    end

    merged = persist_new_highlights!(merged)
    PlaceRanker.rank!(merged.first(MAX_RESULTS), interests: @vibes)
  rescue => e
    Rails.logger.warn("[DestinationHighlights] #{@destination}: #{e.class}: #{e.message}")
    []
  end

  # Walks the merged list and persists every highlight that isn't already
  # a catalog row (place_id blank) AND carries usable coordinates. The
  # returned list keeps the same order but rewrites each persisted entry
  # so its place_id, image_url (from Wikipedia/Wikimedia geosearch via
  # PlaceImageLookup), and from_catalog? state are correct — meaning on
  # the next call for this destination the row comes back through
  # catalog_highlights instead of the LLM tier.
  def persist_new_highlights!(highlights)
    highlights.map do |h|
      next h if h.place_id.present?
      next h unless h.latitude && h.longitude

      place = Places::Seeder.call(
        name: h.name,
        lat: h.latitude,
        lng: h.longitude,
        kind: CATEGORY_TO_KIND[h.category.to_s],
        description: h.summary,
        image_query: h.name
      )
      next h unless place

      Highlight.new(
        slug: "place-#{place.id}",
        name: place.name,
        summary: h.summary.presence || place.description.presence || place.famous_for.presence,
        image_url: h.image_url.presence || place.image_url,
        wikipedia_url: h.wikipedia_url.presence || (place.source_urls.is_a?(Hash) ? place.source_urls["wikipedia"] : nil),
        category: h.category.presence || KIND_TO_CATEGORY[place.kind],
        tags: (Array(h.tags) + [ "from_catalog" ]).uniq,
        place_id: place.id,
        usage_count: place.usage_count,
        latitude: place.latitude&.to_f || h.latitude,
        longitude: place.longitude&.to_f || h.longitude,
        community_rating: place.community_rating,
        community_rating_count: place.community_rating_count.to_i
      )
    end
  end

  # Pulls Place rows near the destination coords (when known) and turns
  # them into Highlight structs. Filtered to "interesting" kinds — no
  # lodging/restaurants here, those belong on the day plan, not the
  # excitement carousel.
  def catalog_highlights
    return [] unless @lat && @lng
    Place.near(@lat, @lng, radius_m: CATALOG_RADIUS_M)
         .where(kind: CATALOG_HIGHLIGHT_KINDS)
         .with_image
         .order(usage_count: :desc, verified: :desc)
         .limit(MAX_RESULTS)
         .map { |p| place_to_highlight(p) }
  rescue => e
    Rails.logger.warn("[DestinationHighlights] catalog #{@destination}: #{e.class}: #{e.message}")
    []
  end

  def place_to_highlight(place)
    Highlight.new(
      slug: "place-#{place.id}",
      name: place.name,
      summary: place.description.presence || place.famous_for.presence,
      image_url: place.image_url,
      wikipedia_url: place.source_urls.is_a?(Hash) ? place.source_urls["wikipedia"] : nil,
      category: KIND_TO_CATEGORY[place.kind] || "scenic",
      tags: [ "from_catalog", ("crowd_favorite" if place.usage_count.to_i >= 3) ].compact,
      place_id: place.id,
      usage_count: place.usage_count,
      latitude: place.latitude&.to_f,
      longitude: place.longitude&.to_f,
      community_rating: place.community_rating,
      community_rating_count: place.community_rating_count.to_i
    )
  end

  # Maps Place.kind → the wizard's VIBES list so catalog rows respect
  # vibe filtering on the highlights step.
  KIND_TO_CATEGORY = {
    "trail" => "adventure", "viewpoint" => "scenic", "landmark" => "history",
    "natural" => "nature", "geological" => "nature", "historic" => "history",
    "museum" => "cultural", "park" => "nature", "beach" => "relaxing",
    "overlook" => "scenic"
  }.freeze

  # Inverse — collapses the wizard's VIBES list to a Place kind so newly-
  # seeded LLM rows get a sensible default kind (Place#kind enum allows
  # nil, but a guess is better than nothing for downstream filtering).
  CATEGORY_TO_KIND = {
    "adventure" => "trail", "scenic" => "viewpoint", "history" => "historic",
    "nature" => "natural", "cultural" => "museum", "relaxing" => "beach",
    "photography" => "viewpoint", "family" => "park", "food" => "restaurant",
    "nightlife" => "landmark", "shopping" => "landmark"
  }.freeze
  private_constant :KIND_TO_CATEGORY, :CATEGORY_TO_KIND

  # Asks the configured AI prompt (slug `destination_highlights_research.v1`,
  # admin-editable) for up to MAX_RESULTS highlights tuned to the picked
  # vibes. Returns Highlight structs (each enriched with a Wikipedia
  # thumbnail/summary when the entry has a matching article). Quiet no-op
  # when the prompt is missing or the AI call fails.
  def claude_research_highlights
    result = Ai::Caller.call(
      slug: "destination_highlights_research.v1",
      variables: { destination: @destination, vibes: @vibes }
    )
    items = result.json
    return [] unless items.is_a?(Array)

    items.first(MAX_RESULTS).filter_map do |item|
      name = item["name"].to_s.strip
      next if name.blank? || junk_name?(name)

      wiki = enrich_with_wikipedia(name)
      llm_lat = numeric_or_nil(item["latitude"])
      llm_lng = numeric_or_nil(item["longitude"])
      Highlight.new(
        slug: slugify(name),
        name: wiki&.name || name,
        summary: (wiki&.summary.presence || clean_extract(item["summary"].to_s)),
        image_url: wiki&.image_url,
        wikipedia_url: wiki&.wikipedia_url,
        category: item["category"].to_s.strip.presence,
        tags: clean_tags(item["tags"]),
        latitude: wiki&.latitude || llm_lat,
        longitude: wiki&.longitude || llm_lng
      )
    end
  rescue => e
    Rails.logger.warn("[DestinationHighlights] claude_research #{@destination}: #{e.class}: #{e.message}")
    []
  end

  def junk_name?(name)
    return true if name.blank?
    return true if name.match?(/\A(List of|Category:|Index of|Outline of|Timeline of)\b/i)
    # Reject anything carrying wikilink/template debris or sub-page anchors —
    # those resolve to nothing useful via the Wikipedia summary endpoint.
    return true if name.match?(/[\[\]\{\}\|#]/)
    # Reject pure-prose paragraphs that snuck through the bullet matcher
    # (entries with embedded sentences are usually not attraction names).
    return true if name.length > 120
    false
  end

  # Asks Wikipedia for articles in `Category:Tourist attractions in <City>`.
  # Tries a couple of category-name variants because Wikipedia is inconsistent
  # ("Tourist attractions in Tokyo" vs "Visitor attractions in Tokyo").
  def wikipedia_category_attractions
    candidates = category_name_candidates
    candidates.each do |cat|
      names = fetch_category_members(cat)
      return names if names.any?
    end
    []
  end

  def category_name_candidates
    base = @destination.split(",").first.to_s.strip
    return [] if base.blank?
    [
      "Tourist attractions in #{base}",
      "Visitor attractions in #{base}",
      "Landmarks in #{base}",
      "Buildings and structures in #{base}"
    ]
  end

  def fetch_category_members(category)
    uri = URI("https://en.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query", list: "categorymembers",
      cmtitle: "Category:#{category}",
      cmlimit: MAX_RESULTS * 2, cmnamespace: 0, # ns:0 = articles only
      format: "json"
    )
    json = http_get_json(uri)
    members = json&.dig("query", "categorymembers") || []
    members.map { |m| m["title"] }.compact
  end

  # Calls Wikivoyage to get the destination's page wikitext, then extracts
  # attraction names from the "See" section. Wikivoyage formats listings
  # with `{{see | name=Foo Bar | ...}}` templates, which is what we look for.
  def wikivoyage_see_names
    title = resolve_wikivoyage_title
    return [] unless title

    text = fetch_wikivoyage_wikitext(title)
    return [] if text.blank?

    see_section = extract_section(text, "See")
    see_section ||= extract_section(text, "See and do")
    return [] if see_section.blank?

    extract_listing_names(see_section).uniq
  end

  def resolve_wikivoyage_title
    uri = URI("https://en.wikivoyage.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "opensearch", search: @destination, limit: 1, namespace: 0, format: "json"
    )
    body = http_get_json(uri)
    titles = body.is_a?(Array) ? body[1] : nil
    titles&.first
  end

  def fetch_wikivoyage_wikitext(title)
    uri = URI("https://en.wikivoyage.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "parse", page: title, prop: "wikitext", format: "json", redirects: 1
    )
    json = http_get_json(uri)
    json.dig("parse", "wikitext", "*")
  end

  # Pulls the contents of a given == Section == from wikitext. Stops at the
  # next top-level heading.
  def extract_section(wikitext, heading)
    pattern = /^==\s*#{Regexp.escape(heading)}\s*==\s*\n(.*?)(?=^==[^=]|\z)/m
    m = wikitext.match(pattern)
    m && m[1]
  end

  # Wikivoyage listings look like:
  #   {{see
  #    | name=Hoover Dam | url= | address=...
  #   }}
  # Some pages use `* '''Name'''` markdown-ish bullets too.
  def extract_listing_names(section)
    names = []
    section.scan(/\{\{\s*(?:see|do)\b(.*?)\}\}/mi) do |body,|
      if (m = body.match(/\|\s*name\s*=\s*([^|\n]+)/i))
        names << m[1].strip
      end
    end
    # Fallback: bold-leading bullets, e.g. * '''Stratosphere Tower''' is...
    section.scan(/^\*\s*'''([^']+)'''/) { |m| names << m[0].strip }
    names.map { |n| n.gsub(/\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/, '\1').strip }.reject(&:blank?)
  end

  # Wikipedia REST summary endpoint: title → { extract, thumbnail.source, content_urls.desktop.page }
  def enrich_with_wikipedia(name)
    title = name.to_s.strip
    return nil if title.blank?

    encoded = URI.encode_www_form_component(title.tr(" ", "_"))
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
    json = http_get_json(uri, allow_404: true)
    return Highlight.new(slug: slugify(title), name: title, summary: nil, image_url: nil, wikipedia_url: nil) if json.nil?

    return nil if json["type"] == "disambiguation"
    # A "Sedona Heritage Museum" lookup can canonicalize to
    # "List of historic properties in Sedona, Arizona" via Wikipedia redirect —
    # filter those out at the enrichment stage too.
    canonical = json["title"].presence || title
    return nil if junk_name?(canonical)

    Highlight.new(
      slug: slugify(title),
      name: canonical,
      summary: clean_extract(json["extract"]),
      image_url: json.dig("thumbnail", "source") || json.dig("originalimage", "source"),
      wikipedia_url: json.dig("content_urls", "desktop", "page"),
      latitude: numeric_or_nil(json.dig("coordinates", "lat")),
      longitude: numeric_or_nil(json.dig("coordinates", "lon"))
    )
  end

  def numeric_or_nil(value)
    return nil if value.nil? || value == ""
    Float(value) rescue nil
  end

  def clean_extract(text)
    return nil if text.blank?
    # Trim to 2 sentences max so cards stay scannable.
    sentences = text.split(/(?<=[.!?])\s+/)
    sentences.first(2).join(" ")
  end

  def slugify(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
  end

  def clean_tags(raw)
    Array(raw).map { |t| t.to_s.strip.downcase.tr("-", "_") }
             .uniq
             .select { |t| ALLOWED_TAGS.include?(t) }
  end

  def http_get_json(uri, allow_404: false)
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = USER_AGENT
    req["Accept"] = "application/json"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 8, open_timeout: 4) do |http|
      http.request(req)
    end

    return nil if allow_404 && res.code == "404"
    return nil unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.warn("[DestinationHighlights] http #{uri}: #{e.class}: #{e.message}")
    nil
  end
end
