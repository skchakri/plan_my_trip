require "test_helper"

class DestinationHighlightsTest < ActiveSupport::TestCase
  setup do
    @service = DestinationHighlights.new("San Francisco")
  end

  test "junk_name? rejects Wikivoyage district-subpage names" do
    # Big-city pages ("San Francisco", "New York City") list districts as
    # bold wikilink bullets whose targets look like "City/District". Those
    # must not become highlight cards — filtering them lets the Wikipedia
    # tourist-attractions fallback engage instead.
    assert @service.send(:junk_name?, "San Francisco/Golden Gate")
    assert @service.send(:junk_name?, "San Francisco/The Avenues#Lands End")
  end

  test "junk_name? still rejects meta pages and template debris" do
    assert @service.send(:junk_name?, "List of public art in San Francisco")
    assert @service.send(:junk_name?, "{{see|name=Foo}}")
    assert @service.send(:junk_name?, "")
  end

  test "junk_name? keeps ordinary attraction names" do
    refute @service.send(:junk_name?, "Fisherman's Wharf, San Francisco")
    refute @service.send(:junk_name?, "Palace of Fine Arts")
    refute @service.send(:junk_name?, "16th Avenue Tiled Steps")
  end

  test "extract_listing_names resolves wikilink bullets to their targets" do
    section = <<~WIKITEXT
      * '''[[San Francisco/Golden Gate|The Marina and the Presidio]]''' has views.
      * '''[[San Francisco Crosstown Trail|Crosstown Trail]]''' spans the city.
      {{see
       | name=Hoover Dam | url= | address=x
      }}
    WIKITEXT
    names = @service.send(:extract_listing_names, section)
    assert_includes names, "Hoover Dam"
    assert_includes names, "San Francisco Crosstown Trail"
    # District target is extracted here but filtered later by junk_name?.
    assert_includes names, "San Francisco/Golden Gate"
  end
end

class DestinationHighlightsConcurrencyTest < ActiveSupport::TestCase
  setup do
    @service = DestinationHighlights.new("San Francisco")
  end

  test "parallel_map preserves order and maps failures to the fallback" do
    out = @service.send(:parallel_map, [ 1, 2, 3, 4, 5 ], max: 3, fallback: ->(i) { "fb-#{i}" }) do |i|
      raise "boom" if i == 3
      sleep(0.01 * (5 - i)) # later items finish first
      i * 10
    end
    assert_equal [ 10, 20, "fb-3", 40, 50 ], out
  end

  test "parallel_map returns nil for failures without a fallback and [] for empty" do
    assert_equal [], @service.send(:parallel_map, [], max: 4) { |i| i }
    assert_equal [ 1, nil ], @service.send(:parallel_map, [ 1, 2 ], max: 4) { |i| i == 2 ? raise("x") : i }
  end

  test "async returns a thread whose value is nil on failure" do
    assert_equal 42, @service.send(:async) { 42 }.value
    assert_nil @service.send(:async) { raise "nope" }.value
  end
end
