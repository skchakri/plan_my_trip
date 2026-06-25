require "test_helper"

class TripTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "u-#{SecureRandom.hex(4)}@test.example",
      password: "password123",
      name: "Tester"
    )
  end

  test "auto-creates an owner membership on create" do
    trip = @user.owned_trips.create!(
      title: "X", start_date: Date.current, end_date: Date.current + 1
    )
    membership = trip.trip_memberships.find_by(user_id: @user.id)
    assert membership.present?, "owner membership should exist"
    assert_equal "owner", membership.role
    assert membership.accepted_at.present?
  end

  test "end_date must be on or after start_date" do
    trip = @user.owned_trips.build(
      title: "Bad", start_date: Date.current, end_date: Date.current - 1
    )
    refute trip.valid?
    assert_includes trip.errors[:end_date], "must be on or after start date"
  end

  test "title_for falls back to the canonical title without a custom_title" do
    trip = @user.owned_trips.create!(
      title: "Vegas", start_date: Date.current, end_date: Date.current + 2
    )
    assert_equal "Vegas", trip.title_for(@user)
  end

  test "pwa urls accept http(s) and blank" do
    trip = @user.owned_trips.build(
      title: "T", pwa_plan_url: "https://example.com/plan.html", pwa_packing_url: ""
    )
    assert trip.valid?
  end

  test "pwa urls reject javascript: and other non-http schemes" do
    trip = @user.owned_trips.build(title: "T", pwa_plan_url: "javascript:alert(1)")
    refute trip.valid?
    assert_includes trip.errors[:pwa_plan_url], "must start with http:// or https://"

    trip = @user.owned_trips.build(title: "T", pwa_packing_url: "data:text/html,<script>1</script>")
    refute trip.valid?
    assert trip.errors[:pwa_packing_url].any?
  end

  test "vehicle_mpg allows nil" do
    trip = @user.owned_trips.build(title: "T", vehicle_mpg: nil)
    assert trip.valid?
  end

  test "vehicle_mpg accepts a positive value within range" do
    trip = @user.owned_trips.build(title: "T", vehicle_mpg: 28.5)
    assert trip.valid?
  end

  test "vehicle_mpg rejects zero, negatives, and absurdly high values" do
    [ 0, -1, 250 ].each do |bad|
      trip = @user.owned_trips.build(title: "T", vehicle_mpg: bad)
      refute trip.valid?, "#{bad} mpg should be invalid"
      assert trip.errors[:vehicle_mpg].any?
    end
  end

  test "own_car? reflects the transport_mode" do
    assert @user.owned_trips.build(title: "T", transport_mode: "own_car").own_car?
    refute @user.owned_trips.build(title: "T", transport_mode: "rental").own_car?
    refute @user.owned_trips.build(title: "T", transport_mode: nil).own_car?
  end
end
