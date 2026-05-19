require "test_helper"

# The stack-points banner is driven by BookingLinks#card_portals — lock in
# the membership → portal mapping so future card additions are explicit.
class BookingLinksCardPortalsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "p-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Pat")
    @trip = @user.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 1)
  end

  test "no cards linked → no portal links surfaced" do
    @user.update!(discount_memberships: {})
    portals = BookingLinks.new(@trip, viewer: @user).card_portals
    assert_empty portals
  end

  test "Chase Sapphire shows the Chase Travel portal" do
    @user.update!(discount_memberships: { "chase_sapphire" => true })
    portals = BookingLinks.new(@trip, viewer: @user).card_portals
    assert_equal 1, portals.size
    assert_match(/Chase/i, portals.first.provider)
    assert_match(%r{https://travel\.chase\.com}, portals.first.url)
  end

  test "all three premium cards surface all three portals" do
    @user.update!(discount_memberships: { "chase_sapphire" => true, "amex_platinum" => true, "capital_one_venture" => true })
    providers = BookingLinks.new(@trip, viewer: @user).card_portals.map(&:provider)
    assert_equal 3, providers.size
    assert(providers.any? { |p| p =~ /Chase/i })
    assert(providers.any? { |p| p =~ /Amex|American Express/i })
    assert(providers.any? { |p| p =~ /Capital One/i })
  end
end
