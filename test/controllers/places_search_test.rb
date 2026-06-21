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
end
