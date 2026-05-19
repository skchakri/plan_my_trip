require "test_helper"

class TripShareLinkTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "u-#{SecureRandom.hex(4)}@test.example",
      password: "password123",
      name: "Tester"
    )
    @trip = @user.owned_trips.create!(
      title: "Trip", start_date: Date.current, end_date: Date.current + 1
    )
  end

  test "fresh trips have no share token by default" do
    assert_nil @trip.share_token
    refute @trip.share_link_active?
  end

  test "enable_share_link! mints a token and marks the link active" do
    @trip.enable_share_link!
    assert @trip.share_token.present?
    assert @trip.share_link_active?
  end

  test "enable_share_link! is idempotent and reuses an existing token" do
    @trip.enable_share_link!
    first = @trip.share_token
    @trip.enable_share_link!
    assert_equal first, @trip.reload.share_token
  end

  test "disable_share_link! preserves the token so re-enable returns the same URL" do
    @trip.enable_share_link!
    token = @trip.share_token
    @trip.disable_share_link!
    refute @trip.share_link_active?
    assert_equal token, @trip.share_token
    @trip.enable_share_link!
    assert_equal token, @trip.share_token
  end

  test "regenerate_share_token! rotates the URL and clears revocation" do
    @trip.enable_share_link!
    first = @trip.share_token
    @trip.disable_share_link!
    @trip.regenerate_share_token!
    refute_equal first, @trip.share_token
    assert @trip.share_link_active?
  end
end
