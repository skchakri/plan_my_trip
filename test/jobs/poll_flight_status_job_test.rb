require "test_helper"

class PollFlightStatusJobTest < ActiveJob::TestCase
  Status = Flights::StatusChecker::Status

  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "Owner")
    @member = User.create!(email: "m-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "Member")
    @trip = @owner.owned_trips.create!(title: "Trip", start_date: Date.current, end_date: Date.current + 2)
    @trip.trip_memberships.create!(user: @member, role: "member", accepted_at: Time.current)
    @flight = @trip.reservations.create!(kind: "flight", status: "parsed",
                                         flight_number: "DL1422", title: "DL 1422",
                                         start_at: 3.hours.from_now)
  end

  teardown { PollFlightStatusJob.checker = nil }

  def stub_checker(status)
    @checked = []
    PollFlightStatusJob.checker = ->(r) { @checked << r; status }
  end

  test "a first-check delay >= 15 min alerts every trip member and stores the snapshot" do
    stub_checker(Status.new(status: "delayed", gate: "A12", terminal: "1", departure_delay_minutes: 45))

    assert_difference -> { Notification.where(kind: "flight_status").count }, +2 do # owner + member
      PollFlightStatusJob.perform_now
    end

    @flight.reload
    assert_equal "delayed", @flight.flight_status
    assert_equal "A12", @flight.gate
    assert_equal 45, @flight.departure_delay_minutes
    assert @flight.flight_checked_at.present?
    assert_match(/Delayed ~45 min/, Notification.where(kind: "flight_status").last.body)
  end

  test "a gate change on a subsequent check alerts" do
    @flight.update_columns(gate: "A12", flight_status: "scheduled", flight_checked_at: 1.hour.ago)
    stub_checker(Status.new(status: "scheduled", gate: "B7", terminal: "1", departure_delay_minutes: 0))

    assert_difference -> { Notification.where(kind: "flight_status").count }, +2 do
      PollFlightStatusJob.perform_now
    end
    assert_match(/New gate: B7/, Notification.where(kind: "flight_status").last.body)
  end

  test "a cancellation alerts" do
    @flight.update_columns(flight_status: "scheduled", flight_checked_at: 1.hour.ago)
    stub_checker(Status.new(status: "cancelled", gate: nil, terminal: nil, departure_delay_minutes: 0))

    assert_difference -> { Notification.where(kind: "flight_status").count }, +2 do
      PollFlightStatusJob.perform_now
    end
    assert_match(/Cancelled/, Notification.where(kind: "flight_status").last.body)
  end

  test "no alert when nothing meaningful changed" do
    @flight.update_columns(gate: "A12", flight_status: "scheduled",
                           departure_delay_minutes: 0, flight_checked_at: 1.hour.ago)
    stub_checker(Status.new(status: "scheduled", gate: "A12", terminal: "1", departure_delay_minutes: 0))

    assert_no_difference -> { Notification.count } do
      PollFlightStatusJob.perform_now
    end
    assert @flight.reload.flight_checked_at > 30.minutes.ago # snapshot still refreshed
  end

  test "only flights departing within the window are checked" do
    @trip.reservations.create!(kind: "flight", status: "parsed", flight_number: "AA1",
                               start_at: 48.hours.from_now) # too far out
    @trip.reservations.create!(kind: "stay", status: "parsed", start_at: 3.hours.from_now) # not a flight
    @trip.reservations.create!(kind: "flight", status: "parsed", flight_number: nil,
                               start_at: 3.hours.from_now) # no number
    stub_checker(Status.new(status: "scheduled", gate: nil, terminal: nil, departure_delay_minutes: 0))

    PollFlightStatusJob.perform_now
    assert_equal [ @flight.id ], @checked.map(&:id)
  end
end
