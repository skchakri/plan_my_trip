require "test_helper"

class TripsBuildingStateTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Ola")
    sign_in_as(@user)
  end

  def trip(status:)
    @user.owned_trips.create!(
      title: "T", destination: "Zion", start_date: Date.current, end_date: Date.current + 1,
      build_status: status
    )
  end

  test "a building trip shows the building page, not the full plan" do
    get trip_path(trip(status: "building"))
    assert_response :success
    assert_includes response.body, "Building your plan"
  end

  test "a failed trip shows the error state with a retry button" do
    t = trip(status: "failed")
    t.update_columns(build_error: "boom")
    get trip_path(t)
    assert_response :success
    assert_includes response.body, "finish this plan"
    assert_includes response.body, rebuild_trip_path(t)
  end

  test "rebuild re-enqueues the job and flips back to building" do
    t = trip(status: "failed")
    assert_enqueued_with(job: BuildTripJob) do
      post rebuild_trip_path(t)
    end
    assert_equal "building", t.reload.build_status
    assert_redirected_to t
  end

  test "failed page surfaces a destination-specific hint and a blank-plan escape hatch" do
    t = trip(status: "failed")
    t.update_columns(build_error: "Geocoder::NotFound: no results for anchor")
    get trip_path(t)
    assert_includes response.body, "pin that destination"
    assert_includes response.body, skip_build_trip_path(t)
    assert_includes response.body, edit_trip_path(t)
  end

  test "skip_build flips the trip to ready and sends the user to edit" do
    t = trip(status: "failed")
    post skip_build_trip_path(t)
    assert_equal "ready", t.reload.build_status
    assert_redirected_to edit_trip_path(t)
  end

  test "build_failure_summary classifies outages and malformed responses" do
    t = trip(status: "failed")
    t.update_columns(build_error: "Net::ReadTimeout")
    assert_equal "Our research service is busy", t.build_failure_summary[:title]
    t.update_columns(build_error: "JSON::ParserError: unexpected token")
    assert_equal "The AI returned something we couldn't use", t.build_failure_summary[:title]
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
