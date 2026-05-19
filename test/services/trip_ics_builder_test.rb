require "test_helper"

class TripIcsBuilderTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(
      email: "o-#{SecureRandom.hex(4)}@test.example",
      password: "password123", name: "Owner"
    )
    @trip = @owner.owned_trips.create!(
      title: "Vegas, baby!",
      destination: "Las Vegas, NV",
      body: "## Day 1\nDrive",
      start_date: Date.new(2026, 6, 1),
      end_date:   Date.new(2026, 6, 3)
    )
    day1 = @trip.trip_days.create!(label: "day-1", title: "Drive", accent: "blue", position: 1, date: @trip.start_date)
    day1.activities.create!(title: "Lunch at Buc-ee's, $10", time_label: "12:30", address: "100 Main St", position: 1)
    day1.activities.create!(title: "Bellagio Fountains", time_label: "8pm", position: 2, latitude: 36.11, longitude: -115.17)
  end

  test "produces a well-formed VCALENDAR with required headers" do
    ics = TripIcsBuilder.new(@trip).to_ics
    assert ics.start_with?("BEGIN:VCALENDAR\r\n"), "must start with VCALENDAR"
    assert ics.include?("VERSION:2.0\r\n")
    assert ics.include?("PRODID:-//Plan My Trip//EN\r\n")
    assert ics.end_with?("END:VCALENDAR\r\n")
  end

  test "uses CRLF line endings everywhere" do
    ics = TripIcsBuilder.new(@trip).to_ics
    refute ics.match?(/(?<!\r)\n/), "ICS lines must terminate with CRLF"
  end

  test "emits one overview event plus one event per activity" do
    ics = TripIcsBuilder.new(@trip).to_ics
    assert_equal 3, ics.scan(/BEGIN:VEVENT/).size
    assert_equal 3, ics.scan(/END:VEVENT/).size
  end

  test "all-day overview event uses exclusive DTEND (end_date + 1)" do
    ics = TripIcsBuilder.new(@trip).to_ics
    assert_match(/DTSTART;VALUE=DATE:20260601/, ics)
    # June 3 (inclusive) → DTEND is June 4
    assert_match(/DTEND;VALUE=DATE:20260604/, ics)
  end

  test "escapes commas and semicolons in text fields" do
    ics = TripIcsBuilder.new(@trip).to_ics
    assert_match(/SUMMARY:Vegas\\, baby!/, ics)
    assert_match(/SUMMARY:Lunch at Buc-ee's\\, \$10/, ics)
  end

  test "emits GEO for activities with coordinates" do
    ics = TripIcsBuilder.new(@trip).to_ics
    assert_match(/GEO:36\.11;-115\.17/, ics)
  end

  test "parses 12:30 and 8pm time labels into the activity start" do
    ics = TripIcsBuilder.new(@trip).to_ics
    assert_match(/DTSTART:20260601T123000Z/, ics)
    assert_match(/DTSTART:20260601T200000Z/, ics)
  end

  test "folds long content lines at 75 octets with CRLF + space" do
    long = "A" * 200
    @trip.trip_days.first.activities.create!(title: long, position: 9)
    ics = TripIcsBuilder.new(@trip).to_ics
    # Find a folded continuation line — must begin with a single space.
    folded_lines = ics.split("\r\n").select { |l| l.start_with?(" ") }
    refute_empty folded_lines, "expected folded continuation lines for long content"
    # No raw line should exceed the byte limit.
    over = ics.split("\r\n").reject { |l| l.start_with?(" ") }.find { |l| l.bytesize > 75 }
    assert_nil over, "line over 75 bytes: #{over&.byteslice(0, 100)}"
  end
end

class TripCalendarEndpointTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(
      email: "o-#{SecureRandom.hex(4)}@test.example",
      password: "password123", name: "Owner"
    )
    @trip = @owner.owned_trips.create!(
      title: "Vegas", start_date: Date.current, end_date: Date.current + 2
    )
  end

  test "auth-gated /trips/:id/calendar.ics requires sign-in" do
    get calendar_trip_path(@trip, format: :ics)
    # Devise returns 401 for non-HTML formats instead of a redirect.
    assert_response :unauthorized
  end

  test "owner gets the ics with correct content type" do
    post user_session_path, params: { user: { email: @owner.email, password: "password123" } }
    get calendar_trip_path(@trip, format: :ics)
    assert_response :success
    assert_match(/text\/calendar/, response.content_type)
    assert response.body.start_with?("BEGIN:VCALENDAR")
  end

  test "public /s/:token/calendar.ics returns the feed when link is active" do
    @trip.enable_share_link!
    get public_trip_calendar_path(@trip.share_token)
    assert_response :success
    assert_match(/text\/calendar/, response.content_type)
  end

  test "public calendar returns 410 once the link is revoked" do
    @trip.enable_share_link!
    token = @trip.share_token
    @trip.disable_share_link!
    get public_trip_calendar_path(token)
    assert_response :gone
  end
end
