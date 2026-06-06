require "test_helper"

# Day-trip create now persists a building shell + enqueues BuildDayTripJob
# instead of assembling inline (mirrors the multi-day wizard).
class DayTripsCreateTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "dc-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Dee")
    sign_in_as(@user)
  end

  ANCHOR = { anchor_label: "Salt Lake City", anchor_lat: 40.7608, anchor_lng: -111.8910, radius_km: 80, date: Date.current.to_s }.freeze

  test "create persists a building day-trip shell and enqueues BuildDayTripJob" do
    assert_difference -> { Trip.count }, 1 do
      assert_enqueued_with(job: BuildDayTripJob) do
        post day_trips_path, params: ANCHOR.merge(selected_slugs: [ "donut-falls", "lisa-falls" ], q: "waterfalls", depart_time: "08:00", return_time: "19:00")
      end
    end
    trip = Trip.order(:created_at).last
    assert trip.day_trip?
    assert_equal "building", trip.build_status
    assert_equal [ "donut-falls", "lisa-falls" ], trip.build_args["selected_slugs"]
    assert_equal "waterfalls", trip.build_args["q"]
    assert_equal 0, trip.trip_days.size, "assembly is deferred to the job"
    assert_redirected_to trip
  end

  test "create with no picks redirects back to suggestions without creating a trip" do
    assert_no_difference -> { Trip.count } do
      post day_trips_path, params: ANCHOR.merge(selected_slugs: [])
    end
    assert_response :redirect
  end

  test "rebuild on a failed day trip re-enqueues BuildDayTripJob (not the multi-day job)" do
    trip = @user.owned_trips.create!(
      title: "Day trip · Home", destination: "Day trip · Home", start_date: Date.current, end_date: Date.current,
      day_trip: true, anchor_label: "Home", anchor_lat: 40.76, anchor_lng: -111.89, max_radius_km: 80,
      build_status: "failed", build_args: { "selected_slugs" => [ "x" ] }
    )
    assert_enqueued_with(job: BuildDayTripJob, args: [ trip.id ]) do
      post rebuild_trip_path(trip)
    end
    assert_equal "building", trip.reload.build_status
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
