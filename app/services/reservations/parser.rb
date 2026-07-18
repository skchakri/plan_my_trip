module Reservations
  # Turns a "parsing" Reservation shell (raw_email already stored by the mailbox)
  # into a structured reservation by running the reservation_parse.v1 prompt over
  # the email body, then wiring up the side-effects (BookingClaim collapse,
  # documents checklist item, day slotting). Idempotent enough to re-run safely.
  #
  #   Reservations::Parser.call(reservation)
  #
  class Parser
    def self.call(...)
      new(...).call
    end

    def initialize(reservation, subject: nil)
      @reservation = reservation
      @subject = subject.to_s
    end

    def call
      trip = @reservation.trip
      result = Ai::Caller.call(
        slug: "reservation_parse.v1",
        variables: { email_body: @reservation.raw_email.to_s, subject: @subject },
        trip: trip,
        user: trip.owner
      )

      data = result.json
      if data.blank? || !data.is_a?(Hash)
        @reservation.update!(status: "failed")
        return @reservation
      end

      apply_fields!(data)
      slot_into_day!
      @reservation.save!

      # Side-effects only fire once we've confidently parsed something.
      collapse_booking_claim!
      add_documents_checklist_item!

      @reservation
    rescue ActiveRecord::RecordNotUnique
      # A duplicate forward of the same confirmation onto the same trip — the
      # partial unique index rejected it. Drop this shell so we don't leave a
      # stranded "parsing" row, and keep the original.
      @reservation.discard
      @reservation
    rescue StandardError => e
      ErrorTracker.report(e, source: "Reservations::Parser", context: { reservation_id: @reservation.id })
      @reservation.update_columns(status: "failed", updated_at: Time.current)
      @reservation
    end

    private

    def apply_fields!(data)
      kind = data["kind"].to_s.downcase
      kind = "other" unless Reservation::KINDS.include?(kind)

      @reservation.assign_attributes(
        status:              "parsed",
        kind:                kind,
        vendor:              presence_str(data["vendor"]),
        confirmation_number: presence_str(data["confirmation_number"]),
        title:               presence_str(data["title"]),
        location:            presence_str(data["location"]),
        address:             presence_str(data["address"]),
        notes:               presence_str(data["notes"]),
        start_at:            parse_time(data["start_at"]),
        end_at:              parse_time(data["end_at"]),
        flight_number:       presence_str(data["flight_number"]),
        carrier_code:        presence_str(data["carrier_code"]),
        parsed:              data
      )
    end

    # If the reservation start lands on one of the trip's days, slot it there so
    # the plan can render it under that day.
    def slot_into_day!
      return if @reservation.start_at.blank?
      date = @reservation.start_at.to_date
      day = @reservation.trip.trip_days.find { |d| d.date == date }
      @reservation.trip_day = day if day
    end

    # Collapse the matching "Book this trip" card — the user has clearly handled
    # this kind of booking. find_or_initialize so a hand-marked claim is reused.
    def collapse_booking_claim!
      kind = @reservation.booking_kind
      return if kind.blank?
      claim = @reservation.trip.booking_claims.find_or_initialize_by(kind: kind)
      note = [ @reservation.vendor, @reservation.confirmation_number && "##{@reservation.confirmation_number}" ]
             .compact_blank.join(" · ")
      claim.note = note if claim.note.blank? && note.present?
      claim.save! if claim.changed?
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      # Non-fatal: the reservation is already parsed; a claim race/validation
      # shouldn't fail the import.
      nil
    end

    # "Bring the <vendor> confirmation" prep item, added once per reservation.
    def add_documents_checklist_item!
      return if @reservation.vendor.blank? && @reservation.confirmation_number.blank?
      label = [ "Bring", @reservation.vendor.presence || @reservation.kind_label.downcase,
               "confirmation", @reservation.confirmation_number && "##{@reservation.confirmation_number}" ]
              .compact.join(" ")
      @reservation.trip.checklist_items.find_or_create_by!(
        scope: "before_trip", category: "Documents", title: label
      )
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def presence_str(value)
      s = value.to_s.strip
      s.presence
    end

    def parse_time(value)
      return nil if value.blank?
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
