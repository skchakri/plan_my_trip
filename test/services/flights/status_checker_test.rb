require "test_helper"

class Flights::StatusCheckerTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "o-#{SecureRandom.hex(4)}@ex.com", password: "password123", name: "O")
    @trip = @owner.owned_trips.create!(title: "T", start_date: Date.current, end_date: Date.current + 1)
    @flight = @trip.reservations.create!(kind: "flight", status: "parsed",
                                         flight_number: "DL1422", start_at: 2.hours.from_now)
  end

  test "returns nil (no network) when no API key is configured" do
    assert_nil AppSetting.get("AERODATABOX_API_KEY"), "precondition: no key in test"
    assert_nil Flights::StatusChecker.call(@flight)
  end

  test "returns nil when the flight has no number" do
    @flight.update_columns(flight_number: nil)
    assert_nil Flights::StatusChecker.call(@flight)
  end

  test "parses an AeroDataBox payload into a Status" do
    checker = Flights::StatusChecker.new(@flight)
    body = [ {
      "status" => "Delayed",
      "departure" => {
        "gate" => "B12", "terminal" => "2",
        "scheduledTime" => { "utc" => "2026-07-18 18:00Z" },
        "revisedTime"   => { "utc" => "2026-07-18 18:35Z" }
      }
    } ].to_json

    status = checker.send(:parse, body)
    assert_equal "delayed", status.status
    assert_equal "B12", status.gate
    assert_equal "2", status.terminal
    assert_equal 35, status.departure_delay_minutes
  end

  test "parse tolerates a missing departure block" do
    checker = Flights::StatusChecker.new(@flight)
    status = checker.send(:parse, [ { "status" => "Boarding" } ].to_json)
    assert_equal "boarding", status.status
    assert_nil status.gate
    assert_nil status.departure_delay_minutes
  end
end
