require "test_helper"

class TripTemplateTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "t-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Tester")
  end

  test "TripTemplate.all returns every defined template" do
    keys = TripTemplate.all.map(&:key)
    assert_includes keys, "utah-parks"
    assert_includes keys, "pnw-loop"
    assert_includes keys, "beach-weekend"
  end

  test "build_for materialises a real owned trip with seeded days" do
    tmpl = TripTemplate.new("utah-parks")
    trip = tmpl.build_for(@user)

    assert_equal @user.id, trip.owner_id
    assert_equal tmpl.title, trip.title
    assert_equal tmpl.duration_days, trip.trip_days.count
    assert_equal tmpl.duration_days, (trip.end_date - trip.start_date).to_i + 1
  end

  test "unknown key raises RecordNotFound" do
    assert_raises(ActiveRecord::RecordNotFound) { TripTemplate.new("not-real") }
  end

  test "build_for shifts start_date when one is given" do
    target = Date.new(2027, 9, 1)
    trip = TripTemplate.new("beach-weekend").build_for(@user, start_date: target)
    assert_equal target, trip.start_date
  end
end

class TripTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "u-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "User")
  end

  test "POST /trip_templates/:key/use creates a trip and redirects to edit" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_difference -> { @user.owned_trips.count }, +1 do
      post use_trip_template_path("utah-parks")
    end
    assert_response :redirect
    assert_match(/\/trips\/.+\/edit\z/, response.location)
  end

  test "unknown template key redirects with an alert" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    post use_trip_template_path("not-a-template")
    assert_redirected_to trips_path
  end
end
