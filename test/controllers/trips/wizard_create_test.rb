require "test_helper"

# The wizard's final step persists a Trip *shell* and enqueues BuildTripJob —
# it must NOT run the slow AI assembly inline.
class Trips::WizardCreateTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "w-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Wes")
    sign_in_as(@user)
    DraftTrip.create!(
      user: @user,
      payload: {
        "destination" => "Moab, UT", "origin" => "Salt Lake City",
        "start_date" => Date.current.to_s, "end_date" => (Date.current + 2).to_s,
        "title" => "Moab long weekend",
        "people" => [ { "name" => "Wes", "age" => nil, "interests" => [] } ],
        "selected_slugs" => []
      }
    )
  end

  test "create persists a building shell and enqueues BuildTripJob without running it" do
    assert_difference -> { Trip.count }, 1 do
      assert_enqueued_with(job: BuildTripJob) do
        post wizard_create_path
      end
    end
    trip = Trip.order(:created_at).last
    assert_equal "building", trip.build_status
    assert_equal "Moab long weekend", trip.title
    assert_equal 0, trip.trip_days.size, "assembly is deferred to the job, not run inline"
    assert_redirected_to trip
  end

  test "the draft is cleared after a successful create" do
    perform_enqueued_jobs do
      post wizard_create_path
    end
    assert_nil DraftTrip.find_by(user_id: @user.id), "draft is reset after hand-off"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
