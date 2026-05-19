# Canonical home of the Places module — Zeitwerk needs a file by this
# name to root the namespace. All module-level helpers (constants,
# `Places.junk_name?`) live here so they aren't lost when reloading
# nested files like places/seeder.rb in development.
module Places
  # Names too generic to be useful as a shared-catalog entry. Claude
  # sometimes emits these as `location_name` for fill-in activities
  # ("check into the hotel", "drive home"), but they'd accrete into
  # meaningless rows reused across unrelated trips. Reject up-front.
  JUNK_NAMES = %w[
    hotel motel home house apartment airbnb b&b inn
    restaurant cafe diner lunch dinner breakfast
    parking lot store grocery
    trailhead trail park stop break
    activity destination origin start end finish
  ].map(&:freeze).to_set.freeze
  JUNK_PHRASES = [ "gas station", "rest stop" ].freeze
  MIN_LENGTH = 4

  # Resolves a highlight/idea card to a real Place row, creating one if
  # the card came from the LLM and isn't in the catalog yet. Used by the
  # review endpoint so any place a user rates becomes a persistent,
  # ratable Place. Does NOT bump usage_count (rating ≠ visiting).
  def self.find_or_create_from_card!(name:, lat: nil, lng: nil, summary: nil, image_url: nil, wikipedia_url: nil, kind: nil, user: nil)
    name = name.to_s.strip
    return nil if name.blank? || junk_name?(name)

    existing = Place.named(name).kept
    if lat.present? && lng.present?
      lat_f, lng_f = lat.to_f, lng.to_f
      delta = 0.005
      existing = existing.where(latitude: (lat_f - delta)..(lat_f + delta),
                                longitude: (lng_f - delta)..(lng_f + delta))
                         .to_a
                         .select { |p| p.distance_m_from(lat_f, lng_f) <= Places::Seeder::PROXIMITY_M }
                         .sort_by { |p| p.distance_m_from(lat_f, lng_f) }
    end
    place = existing.first
    return place if place

    Place.create!(
      name: name,
      latitude: lat,
      longitude: lng,
      kind: kind.presence,
      description: summary.to_s.strip.presence,
      image_url: image_url.presence,
      image_source: image_url.present? ? "wikipedia" : nil,
      image_attribution: image_url.present? ? "Photo from Wikipedia / Wikimedia Commons" : nil,
      source_urls: wikipedia_url.present? ? { "wikipedia" => wikipedia_url } : {},
      contributed_by: user
    )
  end

  def self.junk_name?(name)
    n = name.to_s.strip.downcase
    return true if n.length < MIN_LENGTH
    return true if JUNK_NAMES.include?(n)
    return true if JUNK_PHRASES.any? { |p| n == p }
    # Reject single-word common words. Multi-word names ("Stan's Burger
    # Shack", "Goblin Valley") almost always carry a proper noun.
    return true if n.split(/\s+/).size == 1 && n.match?(/\A[a-z]+\z/)
    false
  end
end
