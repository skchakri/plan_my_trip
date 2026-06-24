require "test_helper"

class ReservationsMailboxTest < ActionMailbox::TestCase
  include ActiveJob::TestHelper

  PARSED_JSON = {
    "kind" => "stay",
    "vendor" => "Marriott",
    "confirmation_number" => "MAR-88231947",
    "title" => "Courtyard Las Vegas Downtown",
    "location" => "Las Vegas, NV",
    "address" => "567 S Las Vegas Blvd, Las Vegas, NV 89101",
    "start_at" => "2026-08-01T15:00:00",
    "end_at" => "2026-08-03T11:00:00",
    "notes" => "1 King Bed"
  }.freeze

  setup do
    @user = User.create!(email: "m-#{SecureRandom.hex(4)}@test.example", password: "password123", name: "Mel")
    @trip = @user.owned_trips.create!(
      title: "Vegas trip", destination: "Las Vegas, NV",
      start_date: Date.new(2026, 8, 1), end_date: Date.new(2026, 8, 3)
    )
    @address = @trip.forwarding_address
  end

  test "routes a forwarded confirmation into a parsing Reservation shell" do
    assert_difference -> { @trip.reservations.count }, 1 do
      receive_inbound_email_from_mail(
        to: @address, from: "traveler@example.com",
        subject: "Fwd: Your reservation is confirmed",
        body: file_fixture("hotel_confirmation.txt").read
      )
    end

    r = @trip.reservations.last
    assert_equal "parsing", r.status
    assert r.raw_email.present?
    assert_includes r.raw_email, "Confirmation Number"
    assert_equal "traveler@example.com", r.source_from
  end

  test "enqueues a ParseReservationJob for the new reservation" do
    assert_enqueued_jobs 1, only: ParseReservationJob do
      receive_inbound_email_from_mail(to: @address, from: "t@example.com", subject: "Fwd", body: "hi")
    end
  end

  test "an unknown token bounces and creates no reservation" do
    inbound = nil
    assert_no_difference -> { Reservation.count } do
      inbound = receive_inbound_email_from_mail(
        to: "trip-doesnotexist@#{Trip.inbound_email_domain}",
        from: "t@example.com", subject: "Fwd", body: "hi"
      )
    end
    assert inbound.bounced?, "unknown token should bounce"
  end

  test "a discarded trip does not receive forwards" do
    @trip.discard
    inbound = receive_inbound_email_from_mail(to: @address, from: "t@example.com", subject: "Fwd", body: "hi")
    assert inbound.bounced?
    assert_equal 0, Reservation.where(trip_id: @trip.id).count
  end

  test "prefers the plain-text part of a multipart forward" do
    receive_inbound_email_from_mail(to: @address, from: "t@example.com") do |mail|
      mail.subject "Fwd: confirmation"
      mail.text_part { |p| p.body "PLAIN: confirmation MAR-1" }
      mail.html_part { |p| p.body "<h1>HTML: confirmation MAR-1</h1>" }
    end
    r = @trip.reservations.last
    assert_includes r.raw_email, "PLAIN:"
    assert_not_includes r.raw_email, "<h1>"
  end

  # Acceptance: a forwarded confirmation walks mailbox → job → parsed reservation
  # visible on the trip, with the AI extraction stubbed.
  test "end to end: a forwarded email becomes a parsed reservation on the trip" do
    with_fake_ai(PARSED_JSON) do
      perform_enqueued_jobs do
        receive_inbound_email_from_mail(
          to: @address, from: "traveler@example.com",
          subject: "Fwd: Your reservation is confirmed",
          body: file_fixture("hotel_confirmation.txt").read
        )
      end
    end

    r = @trip.reservations.reload.first
    assert_equal "parsed", r.status
    assert_equal "stay", r.kind
    assert_equal "MAR-88231947", r.confirmation_number
    assert_equal "Courtyard Las Vegas Downtown", r.title
    # Side effects fired: the stays booking claim collapsed + a documents item added.
    assert @trip.booking_claims.exists?(kind: "stays")
    assert @trip.checklist_items.exists?(category: "Documents")
  end
end
