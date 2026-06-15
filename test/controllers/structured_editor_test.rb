require "test_helper"

class StructuredEditorTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @viewer = User.create!(email: "v-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Vera")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    @trip.trip_memberships.create!(user: @viewer, role: "member", accepted_at: Time.current)
    @day = @trip.trip_days.create!(label: "Day 1", title: "Arrive", position: 0, accent: "gold")
  end

  test "editor page renders for owner" do
    sign_in_as(@owner)
    get edit_plan_trip_path(@trip)
    assert_response :success
    assert_includes response.body, "Edit itinerary"
  end

  test "plain member cannot open the editor" do
    sign_in_as(@viewer)
    get edit_plan_trip_path(@trip)
    assert_response :redirect
  end

  test "add a day and a stop, then sync body" do
    sign_in_as(@owner)
    assert_difference -> { @trip.trip_days.count }, 1 do
      post trip_trip_days_path(@trip), params: { trip_day: { label: "Day 2 — Narrows" } }
    end
    new_day = @trip.trip_days.ordered.last

    assert_difference -> { new_day.activities.count }, 1 do
      post trip_activities_path(@trip), params: { trip_day_id: new_day.id, activity: { title: "The Narrows hike", time_label: "8am" } }
    end

    assert_includes @trip.reload.body.to_s, "The Narrows hike"
  end

  test "update and reorder activities" do
    sign_in_as(@owner)
    a1 = @day.activities.create!(title: "First", position: 0)
    a2 = @day.activities.create!(title: "Second", position: 1)

    patch trip_activity_path(@trip, a1), params: { activity: { title: "First edited" } }
    assert_equal "First edited", a1.reload.title

    patch move_trip_activity_path(@trip, a2, direction: "up")
    assert_equal 0, a2.reload.position
    assert_equal 1, a1.reload.position
  end

  test "delete a day cascades its stops" do
    sign_in_as(@owner)
    @day.activities.create!(title: "Stop", position: 0)
    assert_difference -> { @trip.trip_days.count }, -1 do
      delete trip_trip_day_path(@trip, @day)
    end
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
