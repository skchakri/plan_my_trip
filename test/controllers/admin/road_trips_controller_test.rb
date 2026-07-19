require "test_helper"

class Admin::RoadTripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "adm-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Adm", admin: true)
    @user  = User.create!(email: "usr-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Usr")
  end

  test "non-admin is redirected away" do
    sign_in_as(@user)
    get admin_road_trips_path
    assert_response :redirect
  end

  test "admin index, new, and edit pages render" do
    rt = RoadTrip.create!(origin: "A", destination: "B", title: "AB")
    sign_in_as(@admin)
    get admin_road_trips_path
    assert_response :success
    get new_admin_road_trip_path
    assert_response :success
    get edit_admin_road_trip_path(rt)
    assert_response :success
  end

  test "admin can create a route with JSON stops" do
    sign_in_as(@admin)
    assert_difference "RoadTrip.count", 1 do
      post admin_road_trips_path, params: { road_trip: {
        origin: "Denver", destination: "Moab", title: "Denver to Moab", status: "published",
        stops: '[{"name":"Glenwood Springs","blurb":"Hot springs"}]',
        itinerary: "[]", faqs: "[]"
      } }
    end
    rt = RoadTrip.order(:created_at).last
    assert_equal "denver-to-moab", rt.slug
    assert_equal "Glenwood Springs", rt.stops.first["name"]
    assert_redirected_to admin_road_trips_path
  end

  test "invalid JSON in a jsonb field re-renders with an error" do
    sign_in_as(@admin)
    assert_no_difference "RoadTrip.count" do
      post admin_road_trips_path, params: { road_trip: {
        origin: "A", destination: "B", title: "AB", stops: "{ not json", itinerary: "[]", faqs: "[]"
      } }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "valid JSON"
  end

  test "publish and unpublish toggle status" do
    sign_in_as(@admin)
    rt = RoadTrip.create!(origin: "A", destination: "B", title: "AB", status: "draft")
    post publish_admin_road_trip_path(rt)
    assert rt.reload.published?
    post unpublish_admin_road_trip_path(rt)
    assert_equal "draft", rt.reload.status
  end

  test "destroy soft-deletes the route" do
    sign_in_as(@admin)
    rt = RoadTrip.create!(origin: "A", destination: "B", title: "AB")
    delete admin_road_trip_path(rt)
    assert rt.reload.discarded?
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
