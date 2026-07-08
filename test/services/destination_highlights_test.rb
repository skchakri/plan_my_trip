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
