require "test_helper"

class PlacesIndexTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Uma")
    @a = Place.create!(name: "Goblin Valley", kind: "park", region: "Utah", image_url: "https://x/g.jpg", usage_count: 12, tier: "iconic")
    @b = Place.create!(name: "Sand Dune Cafe", kind: "cafe", region: "Utah", image_url: "https://x/c.jpg", usage_count: 3)
    @no_image = Place.create!(name: "Secret Spot", kind: "park", usage_count: 99)
    sign_in_as(@user)
  end

  test "index lists places with images, most-used first" do
    get places_path
    assert_response :success
    assert_includes response.body, "Goblin Valley"
    assert_includes response.body, "Sand Dune Cafe"
    # no image -> excluded
    assert_not_includes response.body, "Secret Spot"
    # ordering: Goblin (12) before Cafe (3)
    assert_operator response.body.index("Goblin Valley"), :<, response.body.index("Sand Dune Cafe")
  end

  test "filter by kind" do
    get places_path(kind: "cafe")
    assert_response :success
    assert_includes response.body, "Sand Dune Cafe"
    assert_not_includes response.body, "Goblin Valley"
  end

  test "search by name" do
    get places_path(q: "goblin")
    assert_response :success
    assert_includes response.body, "Goblin Valley"
    assert_not_includes response.body, "Sand Dune Cafe"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
