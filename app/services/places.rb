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
