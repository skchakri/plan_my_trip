require "test_helper"

class Reservations::ParserTest < ActiveSupport::TestCase
  # Canned extractor output for the sample hotel confirmation — lets us exercise
  # the parser end to end without hitting Anthropic (matches the suite's no-mock
  # fake-AI seam via Minitest's stub).
  PARSED_JSON = {
    "kind" => "stay",
    "vendor" => "Marriott",
    "confirmation_number" => "MAR-88231947",
    "title" => "Courtyard Las Vegas Downtown",
    "location" => "Las Vegas, NV",
    "address" => "567 S Las Vegas Blvd, Las Vegas, NV 89101",
    "start_at" => "2026-08-01T15:00:00",
    "end_at" => "2026-08-03T11:00:00",
    "notes" => "1 King Bed, Non-Smoking"
  }.freeze

  setup do
    @user = User.create!(email: "p-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Pat")
    @trip = @user.owned_trips.create!(
      title: "Vegas trip", destination: "Las Vegas, NV",
      start_date: Date.new(2026, 8, 1), end_date: Date.new(2026, 8, 3)
    )
    @day = @trip.trip_days.create!(label: "day-1", title: "Arrival", accent: "blue", position: 0, date: Date.new(2026, 8, 1))
  end

  def stub_ai(json, &block)
    with_fake_ai(json, &block)
  end

  def parsing_shell(raw: nil)
    @trip.reservations.create!(
      status: "parsing", kind: "other",
      raw_email: raw || file_fixture("hotel_confirmation.txt").read
    )
  end

  test "parses the AI fields onto the reservation" do
    r = parsing_shell
    stub_ai(PARSED_JSON) { Reservations::Parser.call(r) }
    r.reload

    assert_equal "parsed", r.status
    assert_equal "stay", r.kind
    assert_equal "Marriott", r.vendor
    assert_equal "MAR-88231947", r.confirmation_number
    assert_equal "Courtyard Las Vegas Downtown", r.title
    assert_equal "Las Vegas, NV", r.location
    assert_not_nil r.start_at
    assert_not_nil r.end_at
    assert_equal Date.new(2026, 8, 1), r.start_at.to_date
  end

  test "slots the reservation into the matching trip day" do
    r = parsing_shell
    stub_ai(PARSED_JSON) { Reservations::Parser.call(r) }
    assert_equal @day.id, r.reload.trip_day_id
  end

  test "collapses the matching booking claim" do
    r = parsing_shell
    assert_difference -> { @trip.booking_claims.where(kind: "stays").count }, 1 do
      stub_ai(PARSED_JSON) { Reservations::Parser.call(r) }
    end
    claim = @trip.booking_claims.find_by(kind: "stays")
    assert_includes claim.note.to_s, "Marriott"
    assert_includes claim.note.to_s, "MAR-88231947"
  end

  test "adds a documents checklist item" do
    r = parsing_shell
    assert_difference -> { @trip.checklist_items.where(category: "Documents").count }, 1 do
      stub_ai(PARSED_JSON) { Reservations::Parser.call(r) }
    end
    item = @trip.checklist_items.where(category: "Documents").last
    assert_includes item.title, "Marriott"
    assert_equal "before_trip", item.scope
  end

  test "blank or non-JSON AI output marks the reservation failed" do
    r = parsing_shell
    stub_ai("sorry, I can't read this") { Reservations::Parser.call(r) }
    assert_equal "failed", r.reload.status
  end

  test "a duplicate confirmation forward is discarded, leaving the original" do
    first = parsing_shell
    stub_ai(PARSED_JSON) { Reservations::Parser.call(first) }
    assert_equal "parsed", first.reload.status

    dup = parsing_shell(raw: "second forward of the same booking")
    stub_ai(PARSED_JSON) { Reservations::Parser.call(dup) }

    assert dup.reload.discarded?, "duplicate forward should be soft-deleted"
    assert_equal 1, @trip.reservations.kept.where(confirmation_number: "MAR-88231947").count
  end

  test "an activity reservation collapses the activities booking claim" do
    r = parsing_shell(raw: "tour confirmation")
    json = PARSED_JSON.merge("kind" => "activity", "confirmation_number" => "TOUR-55", "vendor" => "Viator")
    assert_difference -> { @trip.booking_claims.where(kind: "activities").count }, 1 do
      stub_ai(json) { Reservations::Parser.call(r) }
    end
  end
end
