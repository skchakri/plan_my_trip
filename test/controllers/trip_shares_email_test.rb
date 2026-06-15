require "test_helper"

class TripSharesEmailTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Olive")
    @friend = User.create!(email: "friend-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Fran")
    @trip = @owner.owned_trips.create!(
      title: "Zion loop", destination: "Springdale", start_date: Date.current, end_date: Date.current + 2
    )
    sign_in_as(@owner)
  end

  test "sharing with an existing user emails them and grants access" do
    assert_enqueued_emails 1 do
      post trip_shares_path(@trip), params: { email: @friend.email }
    end
    assert @trip.reload.shared_with?(@friend)
  end

  test "the shared email names the trip and inviter" do
    mail = TripSharesMailer.shared(
      @trip.trip_memberships.create!(user: @friend, role: "member", accepted_at: Time.current),
      @owner
    )
    assert_equal [ @friend.email ], mail.to
    assert_includes mail.subject, "Zion loop"
    assert_includes mail.body.encoded, @owner.display_name
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
