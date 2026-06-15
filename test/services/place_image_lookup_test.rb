require "test_helper"

# Guards against the "Donut Falls -> Kenny Rogers single cover" class of bug:
# Wikipedia opensearch is a fuzzy matcher, so a place with no article resolves
# to a phonetically-close unrelated page whose thumbnail is non-free cover art
# or a logo. Two independent defenses, tested as pure predicates (the suite's
# no-network convention).
class PlaceImageLookupTest < ActiveSupport::TestCase
  # --- relevant_match?: opensearch must share the query's distinctive words ---

  test "rejects an opensearch title that shares no significant words" do
    refute PlaceImageLookup.relevant_match?("Donut Falls", "Don't Fall in Love with a Dreamer")
  end

  test "accepts a descriptive expansion that keeps the distinctive word" do
    assert PlaceImageLookup.relevant_match?("Beaver UT", "Beaver, Utah")
  end

  test "accepts a place-name suffix disambiguation" do
    assert PlaceImageLookup.relevant_match?("Bridal Veil Falls", "Bridal Veil Falls, Utah")
  end

  test "accepts when only a non-distinctive descriptor is dropped" do
    assert PlaceImageLookup.relevant_match?("Donut Falls Trailhead", "Donut Falls")
  end

  test "rejects when the query has no significant words to anchor on" do
    refute PlaceImageLookup.relevant_match?("UT", "Don't Fall in Love with a Dreamer")
  end

  # --- usable_photo_url?: non-free language-wiki media is never a place photo ---

  test "rejects a non-free single cover hosted on en.wikipedia" do
    cover = "https://upload.wikimedia.org/wikipedia/en/2/2f/Kenny_Rogers_-_Dont_Fall_single.jpg"
    refute PlaceImageLookup.usable_photo_url?(cover)
  end

  test "rejects non-free media on any language wiki" do
    logo = "https://upload.wikimedia.org/wikipedia/de/1/1a/Some_Logo.png"
    refute PlaceImageLookup.usable_photo_url?(logo)
  end

  test "accepts a freely-licensed Commons photo" do
    photo = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Donut_Falls.jpg/640px-Donut_Falls.jpg"
    assert PlaceImageLookup.usable_photo_url?(photo)
  end

  test "rejects blank urls" do
    refute PlaceImageLookup.usable_photo_url?(nil)
    refute PlaceImageLookup.usable_photo_url?("")
  end
end
