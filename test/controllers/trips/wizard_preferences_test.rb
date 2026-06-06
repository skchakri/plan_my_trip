require "test_helper"

# The destination step now captures pace/budget/preferences; they must persist
# to the draft and onto the Trip at create.
class Trips::WizardPreferencesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "wp-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Win")
    sign_in_as(@user)
  end

  test "save_destination persists trip-style fields to the draft" do
    post wizard_destination_path, params: { wizard: {
      destination: "Moab, UT", start_date: Date.current.to_s, end_date: (Date.current + 2).to_s,
      pace: "packed", budget: "moderate", preferences: "no seafood; one wheelchair user"
    } }
    assert_redirected_to wizard_travelers_path
    draft = DraftTrip.find_by(user_id: @user.id)
    assert_equal "packed", draft.payload["pace"]
    assert_equal "moderate", draft.payload["budget"]
    assert_equal "no seafood; one wheelchair user", draft.payload["preferences"]
  end

  test "create carries trip-style fields onto the Trip shell" do
    DraftTrip.create!(user: @user, payload: {
      "destination" => "Moab, UT", "start_date" => Date.current.to_s, "end_date" => (Date.current + 2).to_s,
      "people" => [ { "name" => "Win" } ], "selected_slugs" => [],
      "pace" => "relaxed", "budget" => "comfortable", "preferences" => "vegetarian"
    })
    assert_enqueued_with(job: BuildTripJob) { post wizard_create_path }
    trip = Trip.order(:created_at).last
    assert_equal "relaxed", trip.pace
    assert_equal "comfortable", trip.budget
    assert_equal "vegetarian", trip.preferences
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
