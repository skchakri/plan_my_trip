module Places
  # Bulk-seeds the Place catalog for a US state or region. Calls the
  # admin-editable `regional_places_research.v1` prompt, which returns
  # 50-80 notable places with name/kind/tier/coords/description/famous_for,
  # then pipes each row through Places::Seeder.
  #
  # Reusable: `Places::RegionalSeeder.call(region: "Utah, USA")`. The
  # Seeder handles dedupe (sub-500m + same lowercased name) and image
  # enrichment via PlaceImageLookup, so reseeding the same region
  # multiple times is safe and idempotent.
  class RegionalSeeder
    def self.call(region:, focus: nil, target_count: nil, exclude: [], user: nil)
      new(region: region, focus: focus, target_count: target_count, exclude: exclude, user: user).call
    end

    def initialize(region:, focus: nil, target_count: nil, exclude: [], user: nil)
      @region = region.to_s.strip
      @focus = focus.to_s.strip.presence
      @target_count = target_count
      @exclude = Array(exclude).map(&:to_s).reject(&:blank?)
      @user = user
    end

    Result = Struct.new(:created, :existing, :skipped, :errored, keyword_init: true)

    def call
      raise ArgumentError, "region required" if @region.blank?

      result = Ai::Caller.call(
        slug: "regional_places_research.v1",
        variables: {
          region: @region, focus: @focus, target_count: @target_count,
          exclude: @exclude
        }
      )
      items = result.json
      return Result.new(created: 0, existing: 0, skipped: 0, errored: 0) unless items.is_a?(Array)

      created = existing = skipped = errored = 0

      items.each do |item|
        next unless item.is_a?(Hash)

        name = item["name"].to_s.strip
        lat = Float(item["lat"]) rescue nil
        lng = Float(item["lng"]) rescue nil

        if name.blank? || lat.nil? || lng.nil? || Places.junk_name?(name)
          skipped += 1
          next
        end

        before = Place.count
        place = Places::Seeder.call(
          name: name,
          lat: lat, lng: lng,
          kind: item["kind"],
          tier: item["tier"],
          region: @region,
          famous_for: item["famous_for"],
          description: item["description"],
          user: @user
        )

        if place.nil?
          errored += 1
        elsif Place.count > before
          created += 1
        else
          existing += 1
        end
      rescue StandardError => e
        Rails.logger.warn("[Places::RegionalSeeder] #{name}: #{e.class}: #{e.message}")
        errored += 1
      end

      Result.new(created: created, existing: existing, skipped: skipped, errored: errored)
    end
  end
end
