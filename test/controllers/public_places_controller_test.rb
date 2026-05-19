require "test_helper"

class PublicPlacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @place = Place.create!(
      name: "Test Mesa",
      canonical_name: "Test Mesa, AZ",
      famous_for: "A made-up landmark for tests",
      description: "Spires of sandstone you can drive right up to.",
      image_url: "https://example.com/test-mesa.jpg",
      kind: "landmark",
      tier: "well_known",
      region: "Arizona, USA",
      latitude: 35.0,
      longitude: -111.0
    )
  end

  test "POST/GET /p/:slug renders without auth" do
    assert @place.slug.present?, "slug should be auto-assigned"
    get public_place_path(@place.slug)
    assert_response :success
    assert_includes response.body, "Test Mesa"
    assert_includes response.body, "TouristAttraction"   # JSON-LD
    assert_includes response.body, %(<link rel="canonical")
  end

  test "GET /p/:slug returns 404 for an unknown slug" do
    get public_place_path("no-such-place-xyz")
    assert_response :not_found
  end

  test "GET /places-sitemap.xml lists the place and uses image:image" do
    get places_sitemap_path
    assert_response :success
    assert_match(/text\/xml|application\/xml/, response.content_type)
    assert_includes response.body, public_place_url(@place.slug)
    assert_includes response.body, "<image:loc>https://example.com/test-mesa.jpg</image:loc>"
  end

  test "place slug is collision-resistant via UUID suffix" do
    other = Place.create!(name: "Test Mesa", region: "Different state")
    refute_equal @place.slug, other.slug
    assert_match(/-\h{6}\z/, other.slug)
  end
end
