module Places
  # Idempotent place seeder. Given a name + coords (plus optional kind,
  # image_query, attributed user), returns either:
  #
  #   - an existing Place (kept) whose lowercased name matches AND
  #     sits within ~500m of the given coords, OR
  #   - a freshly-created Place backed by PlaceImageLookup (Wikipedia
  #     direct → opensearch → 1km geosearch) and the supplied metadata.
  #
  # Each call increments the matched Place's usage_count so we can
  # surface popular places later (autocomplete, "places others loved
  # in Hanksville", etc.).
  class Seeder
    PROXIMITY_M = 500

    def self.call(...)
      new(...).call
    end

    def initialize(name:, lat: nil, lng: nil, kind: nil, image_query: nil, famous_for: nil, description: nil, tier: nil, region: nil, user: nil, defer_image: false)
      @name = name.to_s.strip
      @lat = lat.is_a?(Numeric) ? lat.to_f : (Float(lat) rescue nil)
      @lng = lng.is_a?(Numeric) ? lng.to_f : (Float(lng) rescue nil)
      @kind = sanitize_kind(kind)
      @image_query = image_query.to_s.strip.presence
      @famous_for = famous_for.to_s.strip.presence
      @description = description.to_s.strip.presence
      @tier = sanitize_tier(tier)
      @region = region.to_s.strip.presence
      @user = user
      # When true, create the Place WITHOUT resolving a photo inline — each
      # Wikipedia lookup is ~2s and a trip build does ~16 of them, so the trip
      # builder defers them to BackfillTripImagesJob and the plan returns fast.
      # hero_image_url reads place.image_url live, so the photo appears once the
      # async fill lands (and a post-build broadcast refreshes any open plan).
      @defer_image = defer_image
    end

    def call
      return nil if @name.blank?
      # Skip the entire flow for generic names — better no Place link
      # than a "Hotel" row reused across unrelated trips.
      return nil if Places.junk_name?(@name)

      place = find_existing
      if place
        # Existing row: enrich missing fields so a richer caller (the
        # regional seeder) can upgrade rows first contributed by trip
        # builders with only a name + coords.
        enrich_existing!(place)
        place.record_usage!(by: @user)
      else
        place = create_new
      end
      place
    end

    private

    # Match on case-insensitive name within 500m. Two "Café Diablo" rows
    # exist if there are actually two cafés with that name in different
    # cities — that's by design.
    def find_existing
      candidates = Place.named(@name).kept
      if @lat && @lng
        candidates = candidates.where(latitude:  bounded(@lat, 0.005),
                                      longitude: bounded(@lng, 0.005 / cos_lat(@lat)))
                               .to_a
                               .select { |p| p.distance_m_from(@lat, @lng) <= PROXIMITY_M }
                               .sort_by { |p| p.distance_m_from(@lat, @lng) }
      end
      candidates.first
    end

    def create_new
      image_url = nil
      image_source = nil

      if !@defer_image && (@image_query || @name.present? || (@lat && @lng))
        query = @image_query.presence || @name
        image_url = PlaceImageLookup.call(query, lat: @lat, lng: @lng)
        image_source = "wikipedia" if image_url.present?
      end

      Place.create!(
        name: @name,
        latitude: @lat,
        longitude: @lng,
        kind: @kind,
        tier: @tier,
        region: @region,
        image_url: image_url,
        image_source: image_source,
        image_attribution: image_url.present? ? "Photo from Wikipedia / Wikimedia Commons" : nil,
        famous_for: @famous_for,
        description: @description,
        contributed_by: @user
      )
    rescue ActiveRecord::RecordNotUnique
      # Race condition on concurrent seeders for the same name — retry the find.
      find_existing
    end

    # Fill in fields a previous (shallower) seed couldn't provide.
    # Doesn't overwrite — first contributor's data wins.
    def enrich_existing!(place)
      updates = {}
      updates[:kind] = @kind if @kind && place.kind.blank?
      updates[:tier] = @tier if @tier && place.tier.blank?
      updates[:region] = @region if @region && place.region.blank?
      updates[:description] = @description if @description && place.description.blank?
      updates[:famous_for] = @famous_for if @famous_for && place.famous_for.blank?
      place.update(updates) if updates.any?
    end

    def sanitize_kind(kind)
      k = kind.to_s.strip.downcase
      Place::KINDS.include?(k) ? k : nil
    end

    def sanitize_tier(tier)
      t = tier.to_s.strip.downcase
      Place::TIERS.include?(t) ? t : nil
    end

    def bounded(value, delta)
      (value - delta)..(value + delta)
    end

    def cos_lat(lat)
      [ Math.cos(lat * Math::PI / 180.0).abs, 0.0001 ].max
    end
  end
end
