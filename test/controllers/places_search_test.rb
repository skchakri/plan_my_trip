require "test_helper"

class PlacesSearchTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "ps-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "PS")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "the default autocomplete request returns instantly without the AI discovery pass" do
    # No `discover` param → Places::Discoverer (a 3-5s web-search call) is never
    # invoked. A thin/empty catalog still returns immediately, with discoverable=true
    # so the client fires the slow pass as a background phase 2.
    get search_places_path(q: "qqzz-not-a-real-place", format: :json)
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body["results"]
    assert_equal true, body["discoverable"]
  end

  test "queries under two characters short-circuit to empty" do
    get search_places_path(q: "a", format: :json)
    assert_response :success
    assert_equal [], JSON.parse(response.body)["results"]
  end

  test "cities outrank alphabetically-earlier POIs on a cold catalog" do
    # Regression: with every row at usage 0, the old `usage_count DESC, name ASC`
    # order was alphabetical, so "San Francisco AIDS Foundation" beat the city.
    Place.create!(name: "San Francisco AIDS Foundation", kind: "landmark", usage_count: 0)
    Place.create!(name: "San Francisco Botanical Garden", kind: "park", usage_count: 0)
    city = Place.create!(name: "San Francisco", kind: "city", usage_count: 0)

    get search_places_path(q: "san francisco", format: :json)
    assert_response :success
    results = JSON.parse(response.body)["results"]
    assert_equal city.id, results.first["id"], "the city itself should rank first"
  end

  test "exact name match outranks other cities" do
    Place.create!(name: "Salt Lake County", kind: "city", usage_count: 5)
    exact = Place.create!(name: "Salt Lake City", kind: "city", usage_count: 0)

    get search_places_path(q: "Salt Lake City", format: :json)
    results = JSON.parse(response.body)["results"]
    assert_equal exact.id, results.first["id"]
  end
end
