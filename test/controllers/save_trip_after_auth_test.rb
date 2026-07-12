require "test_helper"

# A logged-out visitor on a public shared trip ("/s/:token") who clicks
# "Sign in / up & save this trip" should land back on that trip after auth,
# where the "Save to my trips" button is one tap away — mirroring how a
# pending invitation token routes to the invitation page.
class SaveTripAfterAuthTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example",
                          password: "password123", name: "Owner")
    @trip = @owner.owned_trips.create!(title: "Vegas", destination: "Las Vegas, NV",
                                       start_date: Date.current, end_date: Date.current + 3)
    @trip.enable_share_link!
    @token = @trip.share_token
  end

  test "sign-in carrying save_trip returns the visitor to the shared trip" do
    visitor = User.create!(email: "v-#{SecureRandom.hex(4)}@test.example",
                           password: "password123", name: "Visitor")
    post user_session_path, params: {
      user: { email: visitor.email, password: "password123" }, save_trip: @token
    }
    assert_redirected_to public_trip_path(@token)
  end

  test "sign-up carrying save_trip returns the new user to the shared trip" do
    post user_registration_path, params: {
      user: { email: "new-#{SecureRandom.hex(4)}@test.example",
              password: "password123", password_confirmation: "password123", name: "New" },
      save_trip: @token
    }
    assert_redirected_to public_trip_path(@token)
  end

  test "no save_trip param leaves the normal post-auth destination unchanged" do
    visitor = User.create!(email: "v2-#{SecureRandom.hex(4)}@test.example",
                           password: "password123", name: "Visitor2")
    post user_session_path, params: { user: { email: visitor.email, password: "password123" } }
    assert_response :redirect
    refute_equal public_trip_path(@token), response.location.sub(%r{\Ahttps?://[^/]+}, "")
  end

  test "a pending invitation token takes precedence over save_trip" do
    invitee = User.create!(email: "inv-#{SecureRandom.hex(4)}@test.example",
                           password: "password123", name: "Invitee")
    inv = @trip.invitations.create!(email: invitee.email, inviter: @owner)
    # Simulate both intents stashed, then sign in — invitation should win.
    get invitation_path(inv.token) # stashes session[:invitation_token] while logged out
    post user_session_path, params: {
      user: { email: invitee.email, password: "password123" }, save_trip: @token
    }
    assert_redirected_to invitation_path(inv.token)
  end
end
