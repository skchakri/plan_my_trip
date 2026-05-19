module Places
  # Generates a 2-3 sentence description for a Place — used to backfill
  # rows where Wikipedia gave us an image but no extract, or where the
  # name is so specific (motel, café) that Wikipedia has nothing at all.
  #
  # Returns { description:, kind: } — kind is Claude's best guess at the
  # Place::KINDS bucket. Caller assigns whichever is appropriate.
  class DescriptionBuilder
    def self.call(place)
      new(place).call
    end

    def initialize(place)
      @place = place
    end

    def call
      result = Ai::Caller.call(
        slug: "place_description.v1",
        variables: {
          name: @place.name,
          lat: @place.latitude,
          lng: @place.longitude,
          famous_for: @place.famous_for,
          kind_hint: @place.kind
        }
      )
      data = result.json
      return { description: nil, kind: nil } unless data.is_a?(Hash)

      kind = data["kind"].to_s.strip.downcase
      kind = nil unless Place::KINDS.include?(kind)
      {
        description: data["description"].to_s.strip.presence,
        kind: kind
      }
    rescue StandardError => e
      Rails.logger.warn("[Places::DescriptionBuilder] #{@place.name}: #{e.class}: #{e.message}")
      { description: nil, kind: nil }
    end
  end
end
