require "test_helper"

# The highlights step renders a shell with a lazy turbo-frame; the slow
# DestinationHighlights + brief research runs in #highlights_results (hit by the
# frame), so the step itself never blocks on AI/HTTP. We assert the shell only —
# the results endpoint does real Wikivoyage/Wikipedia lookups we don't want in a
# unit test.
class Trips::WizardHighlightsLazyTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "h-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Hil")
    sign_in_as(@user)
    DraftTrip.create!(
      user: @user,
      payload: {
        "destination" => "Moab, UT",
        "start_date" => Date.current.to_s, "end_date" => (Date.current + 2).to_s,
        "people" => [ { "name" => "Hil", "age" => nil, "interests" => [] } ]
      }
    )
  end

  test "highlights step renders a lazy frame pointing at the results endpoint, not the cards" do
    get wizard_highlights_path
    assert_response :success
    assert_includes response.body, %(id="wizard-highlights")
    assert_includes response.body, "/trip_wizard/highlights/results"
    assert_includes response.body, "Curating the must-sees"
    # The picker grid itself is NOT in the shell — it loads in the frame.
    refute_includes response.body, "Continue → Review"
  end

  test "highlights step still requires a destination" do
    DraftTrip.where(user_id: @user.id).delete_all
    DraftTrip.create!(user: @user, payload: { "people" => [ { "name" => "Hil" } ] })
    get wizard_highlights_path
    assert_redirected_to wizard_destination_path
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
