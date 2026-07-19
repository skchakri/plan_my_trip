require "test_helper"

# Road-trip pages deep-link into the wizard pre-filled:
# /trip_wizard/destination?origin=…&destination=…&transport_mode=…
class Trips::WizardDeeplinkTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "wz-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Wiz")
    sign_in_as(@user)
  end

  test "destination step pre-fills origin and destination from query params" do
    get wizard_destination_path(origin: "San Francisco", destination: "Las Vegas", transport_mode: "own_car")
    assert_response :success
    assert_includes response.body, "San Francisco"
    assert_includes response.body, "Las Vegas"
  end

  test "query params never clobber an in-progress draft" do
    # Seed a draft with an existing destination.
    post wizard_destination_path, params: { wizard: { origin: "Seattle", destination: "Portland",
                                                      start_date: (Date.current + 3).to_s, end_date: (Date.current + 5).to_s } }
    # Now hit the deep-link with different params.
    get wizard_destination_path(origin: "Denver", destination: "Moab")
    assert_response :success
    assert_includes response.body, "Portland"
    refute_includes response.body, "Moab"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
