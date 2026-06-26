require "test_helper"

# Places::Deduper — catalog hygiene that merges duplicate Place rows
# (Great Salt Lake x4, Antelope Island x2, name-variant pink lakes, ...)
# accumulated by the seed/persist path. Dry-run by default; commits only
# when asked, re-pointing activities/reviews onto the canonical row.
class PlacesDeduperTest < ActiveSupport::TestCase
  def place(name, lat, lng, **attrs)
    Place.create!(name: name, kind: "natural", latitude: lat, longitude: lng,
                  image_url: "https://example.com/#{name.parameterize}.jpg", **attrs)
  end

  test "co-located rows form a duplicate group; dry run reports but does not discard" do
    place("Antelope Island State Park", 41.00, -112.20, usage_count: 2)
    place("Antelope Island State Park", 41.00, -112.20, usage_count: 3)

    result = Places::Deduper.call(commit: false)
    assert_equal 1, result.groups.size
    assert_equal 1, result.groups.first[:redundant].size
    assert_equal 2, Place.kept.count, "dry run must not discard anything"
  end

  test "commit keeps one canonical row, discards the rest, and sums usage_count" do
    place("Antelope Island State Park", 41.00, -112.20, usage_count: 2)
    place("Antelope Island State Park", 41.00, -112.20, usage_count: 3)

    result = Places::Deduper.call(commit: true)
    assert_equal 1, Place.kept.count
    assert_equal 5, Place.kept.first.usage_count, "usage of the discarded dup should fold into the canonical"
    assert_equal 1, result.groups.first[:redundant].size
  end

  test "the verified row wins as canonical even with lower usage" do
    high = place("Antelope Island State Park", 41.00, -112.20, usage_count: 10, verified: false)
    low  = place("Antelope Island State Park", 41.00, -112.20, usage_count: 1,  verified: true)

    Places::Deduper.call(commit: true)
    survivor = Place.kept.first
    assert_equal low.id, survivor.id, "verified row should be chosen as canonical"
    assert high.reload.discarded?
    assert_equal 11, survivor.usage_count
  end

  test "reordered / parenthetical name variants at the same spot are merged" do
    place("Lake Hillier (Pink Lake)", -33.91, 121.70)
    place("Pink Lake (Lake Hillier)", -33.91, 121.70) # same significant words, reordered

    result = Places::Deduper.call(commit: true)
    assert_equal 1, Place.kept.count
    assert_equal 1, result.groups.size
  end

  test "identical names far apart are NOT merged (proximity guard)" do
    place("Crystal Lake", 40.00, -111.00)
    place("Crystal Lake", 44.00, -111.00) # ~445 km away — different lake, same name

    result = Places::Deduper.call(commit: true)
    assert_equal 2, Place.kept.count, "same-named places in different regions must stay separate"
    assert_empty result.groups
  end

  test "co-located but differently-named places are NOT merged" do
    # Regression: dense areas (an Eataly food hall, a casino district) pack many
    # distinct venues within metres — proximity alone must never merge them.
    place("La Pizza & La Pasta", 36.10, -115.17)
    place("NoMad Bar at Park MGM", 36.1001, -115.1701) # ~15 m away, unrelated name
    place("T-Mobile Arena", 36.1005, -115.1705)

    result = Places::Deduper.call(commit: true)
    assert_equal 3, Place.kept.count, "distinct venues that merely sit close together must stay separate"
    assert_empty result.groups
  end

  test "commit re-points activities from the discarded duplicate onto the canonical" do
    canonical = place("Antelope Island State Park", 41.00, -112.20, usage_count: 5, verified: true)
    dup       = place("Antelope Island State Park", 41.00, -112.20, usage_count: 1)

    user = User.create!(email: "d-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "D")
    trip = user.owned_trips.create!(title: "T", destination: "X", start_date: Date.current, end_date: Date.current, build_status: "ready")
    day  = trip.trip_days.create!(label: "day-1", title: "Day 1", accent: "blue", position: 0, date: trip.start_date)
    act  = day.activities.create!(title: "Visit", position: 0, place: dup)

    Places::Deduper.call(commit: true)
    assert_equal canonical.id, act.reload.place_id, "activity should follow the merge to the canonical row"
    assert dup.reload.discarded?
  end
end
