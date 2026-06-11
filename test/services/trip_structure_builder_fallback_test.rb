require "test_helper"

# The deterministic fallback runs whenever the structure AI call fails (it timed
# out for real on claude_cli, producing 7-day trips with the same 3 activities
# every day). It must spread the chosen highlights across the days so no two
# days are identical.
class TripStructureBuilderFallbackTest < ActiveSupport::TestCase
  def builder(highlights:, days:)
    TripStructureBuilder.new(
      destination: "Disneyland Resort",
      start_date: Date.new(2026, 6, 30),
      end_date: Date.new(2026, 6, 30) + (days - 1),
      highlights: highlights
    )
  end

  def highlight(name)
    { name: name, summary: "About #{name}" }
  end

  test "fallback spreads highlights across days instead of repeating them" do
    hls = %w[Pirates Galaxy Mansion].map { |n| highlight(n) }
    structure = builder(highlights: hls, days: 7).send(:fallback)

    assert_equal 7, structure["days"].size

    # Each highlight appears exactly once across the whole trip — the old bug
    # put all three on every single day.
    all_titles = structure["days"].flat_map { |d| d["activities"].map { |a| a["title"] } }
    assert_equal 1, all_titles.count("Pirates")
    assert_equal 1, all_titles.count("Galaxy")
    assert_equal 1, all_titles.count("Mansion")

    # Days are not all identical, and the leftover days are open "explore" slots.
    signatures = structure["days"].map { |d| d["activities"].map { |a| a["title"] } }
    assert_operator signatures.uniq.size, :>, 1, "days must not all be identical"
    explore_days = structure["days"].count { |d| d["activities"].any? { |a| a["title"].start_with?("Explore") } }
    assert_equal 4, explore_days
  end

  test "fallback chunks evenly when there are more highlights than days" do
    hls = (1..6).map { |i| highlight("H#{i}") }
    structure = builder(highlights: hls, days: 3).send(:fallback)

    assert_equal 3, structure["days"].size
    assert_equal [ 2, 2, 2 ], structure["days"].map { |d| d["activities"].size }
    all_titles = structure["days"].flat_map { |d| d["activities"].map { |a| a["title"] } }
    assert_equal hls.map { |h| h[:name] }.sort, all_titles.sort
  end

  test "fallback with no highlights gives each day a single distinct open slot" do
    structure = builder(highlights: [], days: 2).send(:fallback)
    assert_equal 2, structure["days"].size
    structure["days"].each do |d|
      assert_equal 1, d["activities"].size
      assert_equal "Explore Disneyland Resort", d["activities"].first["title"]
    end
  end
end
