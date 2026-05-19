module Places
  # AI-backed place lookup for the typeahead. Takes a free-form query
  # (the typed string in the destination / home-base inputs), asks
  # Claude to resolve it to real-world places, persists each result
  # through Places::Seeder so the catalog grows, and returns the
  # persisted Place rows.
  #
  # The hot path is two-tier:
  #   1. Rails.cache.fetch(30d, normalized_query) → list of Place IDs.
  #   2. Place.where(id: ids).kept, fresh-read each call so the latest
  #      DB rows (image_url, usage_count, etc.) come through.
  #
  # Falls back silently to [] on AI errors or empty replies — the
  # caller (PlacesController#search) tops up with whatever LIKE
  # matches it already has.
  class Discoverer
    CACHE_TTL = 30.days
    CACHE_PREFIX = "places/discoverer/v1".freeze
    MIN_QUERY_LENGTH = 4
    MAX_RESULTS = 8

    def self.call(query, user: nil)
      new(query, user: user).call
    end

    def initialize(query, user: nil)
      @query = query.to_s.strip
      @user = user
    end

    def call
      return [] if @query.length < MIN_QUERY_LENGTH

      ids = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { discover_and_seed_ids }
      return [] if ids.blank?

      Place.kept.where(id: ids).index_by(&:id).values_at(*ids).compact
    end

    private

    def cache_key
      "#{CACHE_PREFIX}/#{Digest::SHA256.hexdigest(@query.downcase)}"
    end

    def discover_and_seed_ids
      items = ai_lookup
      return [] if items.blank?

      ids = []
      items.first(MAX_RESULTS).each do |item|
        next if item["name"].to_s.strip.blank?
        lat = numeric_or_nil(item["latitude"])
        lng = numeric_or_nil(item["longitude"])
        next unless lat && lng

        place = Places::Seeder.call(
          name: item["name"],
          lat: lat,
          lng: lng,
          kind: sanitize_kind(item["kind"]),
          description: item["description"].to_s.strip.presence,
          region: item["region"].to_s.strip.presence,
          image_query: item["name"],
          user: @user
        )
        ids << place.id if place
      end
      ids
    rescue StandardError => e
      Rails.logger.warn("[Places::Discoverer] #{@query}: #{e.class}: #{e.message}")
      []
    end

    def ai_lookup
      result = Ai::Caller.call(
        slug: "place_search.v1",
        variables: { query: @query }
      )
      json = result.json
      json.is_a?(Array) ? json : []
    rescue StandardError => e
      Rails.logger.warn("[Places::Discoverer] ai #{@query}: #{e.class}: #{e.message}")
      []
    end

    def sanitize_kind(value)
      return nil if value.blank?
      v = value.to_s.strip.downcase
      Place::KINDS.include?(v) ? v : nil
    end

    def numeric_or_nil(value)
      return nil if value.nil? || value == ""
      Float(value) rescue nil
    end
  end
end
