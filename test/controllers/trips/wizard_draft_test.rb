require "test_helper"

class Trips::WizardDraftTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "w-#{SecureRandom.hex(4)}@test.example",
                         password: "password123", name: "Owner")
    sign_in_as(@user)
  end

  test "save_destination persists the draft to DraftTrip" do
    assert_difference -> { DraftTrip.count }, +1 do
      post wizard_destination_path, params: {
        wizard: {
          title:           "Vegas",
          destination:     "Las Vegas, NV",
          origin:          "Salt Lake City, UT",
          start_date:      Date.current.to_s,
          end_date:        (Date.current + 2).to_s,
          traveler_count:  "2"
        }
      }
    end
    assert_redirected_to wizard_travelers_path

    draft = DraftTrip.find_by(user_id: @user.id)
    assert_equal "Las Vegas, NV", draft.payload["destination"]
    assert_equal "save_destination", draft.step
    assert draft.expires_at > Time.current
  end

  test "draft survives across a fresh session cookie" do
    post wizard_destination_path, params: {
      wizard: {
        title: "Vegas", destination: "Las Vegas, NV",
        start_date: Date.current.to_s, end_date: (Date.current + 1).to_s,
        traveler_count: "1"
      }
    }
    reset!                # new session jar — simulates browser cookie clear
    sign_in_as(@user)
    get wizard_destination_path
    assert_response :success
    assert_includes response.body, "Las Vegas, NV"
  end

  test "reset wipes the draft row" do
    DraftTrip.create!(user: @user,
                      payload: { "destination" => "Phoenix" },
                      expires_at: 1.hour.from_now)
    delete wizard_reset_path
    assert_nil DraftTrip.find_by(user_id: @user.id)
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
