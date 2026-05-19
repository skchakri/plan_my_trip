require "test_helper"

# Affiliate-tag injection for providers with a URL-param affiliate
# scheme. When no ENV-driven IDs are configured (the default in tests),
# links stay plain so we never accidentally ship someone else's tag.
class BookingLinksAffiliatesTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "a-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Alex")
    @trip = @user.owned_trips.create!(
      title: "T",
      destination: "Las Vegas",
      origin: "SLC",
      start_date: Date.current,
      end_date: Date.current + 2
    )
    @original = Rails.application.config.x.affiliates.dup
  end

  teardown { Rails.application.config.x.affiliates = @original }

  def with_affiliates(**overrides)
    Rails.application.config.x.affiliates = ActiveSupport::OrderedOptions.new.merge!(@original.to_h.merge(overrides))
  end

  test "no affiliate IDs configured → links carry no affiliate params" do
    with_affiliates(booking_com_aid: nil, getyourguide_partner_id: nil, viator_pid: nil, skyscanner_associateid: nil, travelpayouts_marker: nil)
    links = BookingLinks.new(@trip, viewer: @user)

    assert_no_match(/[?&]aid=/, links.hotels.find { |l| l.provider == "Booking.com" }.url)
    assert_no_match(/[?&]partner_id=/, links.activities.find { |l| l.provider == "GetYourGuide" }.url)
    assert_no_match(/[?&]pid=/, links.activities.find { |l| l.provider == "Viator" }.url)
    assert_no_match(/[?&]associateid=|[?&]marker=/, links.flights.find { |l| l.provider == "Skyscanner" }.url)
  end

  test "Booking.com gets aid + label when configured" do
    with_affiliates(booking_com_aid: "1234567", booking_com_label: "plan_my_trip")
    url = BookingLinks.new(@trip, viewer: @user).hotels.find { |l| l.provider == "Booking.com" }.url
    assert_match(/[?&]aid=1234567/, url)
    assert_match(/[?&]label=plan_my_trip-/, url)
  end

  test "GetYourGuide gets partner_id + cmp when configured" do
    with_affiliates(getyourguide_partner_id: "ABCDEF")
    url = BookingLinks.new(@trip, viewer: @user).activities.find { |l| l.provider == "GetYourGuide" }.url
    assert_match(/[?&]partner_id=ABCDEF/, url)
    assert_match(/[?&]cmp=/, url)
  end

  test "Viator gets pid + mcid when configured" do
    with_affiliates(viator_pid: "P12345", viator_mcid: "42383")
    url = BookingLinks.new(@trip, viewer: @user).activities.find { |l| l.provider == "Viator" }.url
    assert_match(/[?&]pid=P12345/, url)
    assert_match(/[?&]mcid=42383/, url)
  end

  test "Skyscanner direct associateid wins over Travelpayouts marker" do
    with_affiliates(skyscanner_associateid: "DIRECT9", travelpayouts_marker: "TP1")
    url = BookingLinks.new(@trip, viewer: @user).flights.find { |l| l.provider == "Skyscanner" }.url
    assert_match(/[?&]associateid=DIRECT9/, url)
    assert_no_match(/[?&]marker=/, url)
  end

  test "Skyscanner falls back to Travelpayouts marker when no direct ID" do
    with_affiliates(skyscanner_associateid: nil, travelpayouts_marker: "TP1")
    url = BookingLinks.new(@trip, viewer: @user).flights.find { |l| l.provider == "Skyscanner" }.url
    assert_match(/[?&]marker=TP1/, url)
    assert_match(/[?&]sub_id=/, url)
  end

  test "tracking sub-id is stable across calls for the same trip" do
    with_affiliates(booking_com_aid: "1234567")
    url1 = BookingLinks.new(@trip, viewer: @user).hotels.find { |l| l.provider == "Booking.com" }.url
    url2 = BookingLinks.new(@trip, viewer: @user).hotels.find { |l| l.provider == "Booking.com" }.url
    assert_equal url1, url2
  end
end
