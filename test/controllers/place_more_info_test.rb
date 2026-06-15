require "test_helper"

# Covers the click-to-load "More about this place" frames on the day-trip idea
# modal and the place page. With no seeded AiPrompt row, HighlightDetail
# degrades to its fallback (summary + category), so these stay offline and
# deterministic while still rendering the frame + section markup.
class PlaceMoreInfoTest < ActionDispatch::IntegrationTest
  ANCHOR = { anchor_label: "Salt Lake City", anchor_lat: 40.7608, anchor_lng: -111.8910, radius_km: 80 }.freeze

  setup do
    @user = User.create!(email: "m-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Mia")
    @place = Place.create!(
      name: "Testarossa Falls",
      latitude: 40.75, longitude: -111.88,
      kind: "trail",
      image_url: "https://example.com/falls.jpg",
      description: "A roaring two-tier waterfall twenty minutes up a shaded canyon."
    )
    sign_in_as(@user)
  end

  test "idea_more renders the more-info frame for a catalog idea" do
    get day_trip_idea_more_path(ANCHOR.merge(slug: "place-#{@place.id}"))
    assert_response :success
    assert_includes response.body, %(id="idea-more")
    # Fallback overview = the idea summary (the place description).
    assert_includes response.body, "roaring two-tier waterfall"
  end

  test "idea_more 404s for an unknown slug" do
    get day_trip_idea_more_path(ANCHOR.merge(slug: "nope"))
    assert_response :not_found
  end

  test "idea modal carries the click-to-load more-info button" do
    get day_trip_idea_detail_path(ANCHOR.merge(slug: "place-#{@place.id}"))
    assert_response :success
    assert_includes response.body, "More about this place"
    assert_includes response.body, "/day_trips/idea_more"
  end

  test "place page more_info renders the frame" do
    get more_info_place_path(@place.id)
    assert_response :success
    assert_includes response.body, %(id="place-more-info")
    assert_includes response.body, "roaring two-tier waterfall"
  end

  test "place page shows the more-info button" do
    get place_path(@place.id)
    assert_response :success
    assert_includes response.body, "More about this place"
    assert_includes response.body, more_info_place_path(@place.reload.slug.presence || @place.id)
  end

  test "more_info requires authentication" do
    delete destroy_user_session_path
    get more_info_place_path(@place.id)
    assert_response :redirect
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
