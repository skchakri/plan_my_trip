require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "r-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Rae")
    @trip = @user.owned_trips.create!(
      title: "Reno weekend", destination: "Reno, NV",
      start_date: Date.new(2026, 8, 1), end_date: Date.new(2026, 8, 3)
    )
  end

  test "validates kind and status inclusion" do
    r = @trip.reservations.new(kind: "bogus", status: "parsing")
    assert_not r.valid?
    assert_includes r.errors[:kind], "is not included in the list"

    r.kind = "stay"
    r.status = "weird"
    assert_not r.valid?
    assert_includes r.errors[:status], "is not included in the list"
  end

  test "booking_kind maps reservation kinds onto BookingClaim kinds" do
    assert_equal "stays",      @trip.reservations.new(kind: "stay").booking_kind
    assert_equal "flights",    @trip.reservations.new(kind: "flight").booking_kind
    assert_equal "cars",       @trip.reservations.new(kind: "car").booking_kind
    assert_equal "activities", @trip.reservations.new(kind: "activity").booking_kind
    assert_nil @trip.reservations.new(kind: "rail").booking_kind
    assert_nil @trip.reservations.new(kind: "other").booking_kind
  end

  test "headline falls back from title to vendor to kind label" do
    assert_equal "Courtyard Reno", @trip.reservations.new(kind: "stay", title: "Courtyard Reno", vendor: "Marriott").headline
    assert_equal "Marriott", @trip.reservations.new(kind: "stay", vendor: "Marriott").headline
    assert_equal "Stay", @trip.reservations.new(kind: "stay").headline
  end

  test "raw_email is truncated to the byte cap on save" do
    big = "x" * (Reservation::MAX_RAW_EMAIL_BYTES + 5_000)
    r = @trip.reservations.create!(kind: "other", status: "parsing", raw_email: big)
    assert_operator r.raw_email.bytesize, :<=, Reservation::MAX_RAW_EMAIL_BYTES
  end

  test "discard hides the reservation from the trip's kept association" do
    r = @trip.reservations.create!(kind: "stay", status: "parsed", confirmation_number: "AAA111")
    assert_includes @trip.reservations.reload, r
    r.discard
    assert_not_includes @trip.reservations.reload, r
  end

  test "the unique index rejects a duplicate confirmation on the same trip" do
    @trip.reservations.create!(kind: "stay", status: "parsed", confirmation_number: "DUP999")
    assert_raises(ActiveRecord::RecordNotUnique) do
      @trip.reservations.create!(kind: "flight", status: "parsed", confirmation_number: "DUP999")
    end
  end

  test "a discarded reservation frees its confirmation number for re-import" do
    first = @trip.reservations.create!(kind: "stay", status: "parsed", confirmation_number: "FREE1")
    first.discard
    assert_nothing_raised do
      @trip.reservations.create!(kind: "stay", status: "parsed", confirmation_number: "FREE1")
    end
  end
end
