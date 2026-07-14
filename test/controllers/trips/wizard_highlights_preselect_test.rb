require "test_helper"

# Step 3 surfaces step-1's must-include favourites: highlights whose name
# matches one start pre-selected (first visit only) and get a "Must include"
# badge; unmatched favourites show in the "Already in your plan" strip.
class Trips::WizardHighlightsPreselectTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "hp-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Pre")
    sign_in_as(@user)
  end

  test "first visit pre-selects highlights matching must-includes and badges them" do
    draft!("must_includes" => [ "Disneyland — 2 days", "Yosemite", "LA beach" ])
    with_stubbed_research([ hl("disneyland-park", "Disneyland Park"), hl("yosemite-np", "Yosemite National Park"), hl("golden-gate", "Golden Gate Bridge") ]) do
      get wizard_highlights_results_path
    end
    assert_response :success
    assert_includes response.body, %(name="wizard[selected_slugs][]" id="wizard_selected_slugs_" value="disneyland-park")
    assert_includes response.body, %(value="yosemite-np")
    refute_includes response.body, %(value="golden-gate")
    assert_includes response.body, "Must include"          # card badge
    assert_includes response.body, "Already in your plan"  # strip
    assert_includes response.body, "LA beach"              # unmatched, still shown
  end

  test "a saved selection is respected — must-includes are not forced back in" do
    draft!("must_includes" => [ "Yosemite" ], "selected_slugs" => [])
    with_stubbed_research([ hl("yosemite-np", "Yosemite National Park") ]) do
      get wizard_highlights_results_path
    end
    assert_response :success
    refute_includes response.body, %(value="yosemite-np")
    # Still visibly anchored, just not selected.
    assert_includes response.body, "Already in your plan"
  end

  test "short favourites don't fuzzy-match half the grid" do
    draft!("must_includes" => [ "LA" ])
    with_stubbed_research([ hl("la-brea", "La Brea Tar Pits"), hl("lake-hollywood", "Lake Hollywood Park") ]) do
      get wizard_highlights_results_path
    end
    assert_response :success
    refute_includes response.body, %(value="la-brea")
    refute_includes response.body, %(value="lake-hollywood")
  end

  private

  def draft!(extra)
    DraftTrip.create!(user: @user, payload: {
      "destination" => "California", "start_date" => Date.current.to_s,
      "end_date" => (Date.current + 7).to_s,
      "people" => [ { "name" => "Pre" } ]
    }.merge(extra))
  end

  def hl(slug, name)
    DestinationHighlights::Highlight.new(
      slug: slug, name: name, summary: "A beloved spot.", category: "nature",
      tags: [], usage_count: 0, rank: 1, score: 1.0
    )
  end

  # Repo pattern: swap the class-level .call seams, restore after (no
  # minitest #stub in Minitest 6).
  def with_stubbed_research(highlights)
    dh = DestinationHighlights.singleton_class
    db = DestinationBrief.singleton_class
    orig_dh = DestinationHighlights.method(:call)
    orig_db = DestinationBrief.method(:call)
    dh.send(:define_method, :call) { |*_a, **_k| highlights }
    db.send(:define_method, :call) { |*_a, **_k| DestinationBrief::EMPTY }
    yield
  ensure
    dh.send(:define_method, :call, orig_dh)
    db.send(:define_method, :call, orig_db)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
