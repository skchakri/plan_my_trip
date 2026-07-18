class PollFlightStatusJob < ApplicationJob
  queue_as :default

  # Injectable status backend so tests can swap a fake (this suite avoids mocks).
  # Defaults to the real Flights::StatusChecker.
  class << self
    attr_writer :checker

    def checker
      @checker || Flights::StatusChecker
    end
  end

  # Refresh every flight departing in the next 24h and alert trip members when
  # the gate, delay, or cancellation state changes. Best-effort — a flight the
  # checker can't resolve (or no API key) is simply skipped.
  def perform
    Reservation.trackable_flights.find_each do |reservation|
      status = self.class.checker.call(reservation)
      next unless status

      apply(reservation, status)
    end
  end

  private

  def apply(reservation, status)
    first_check = reservation.flight_checked_at.nil?
    changes = []

    if !first_check && status.gate.present? && status.gate != reservation.gate
      changes << "New gate: #{status.gate}"
    end

    delay = status.departure_delay_minutes.to_i
    if delay >= 15 && (first_check || delay != reservation.departure_delay_minutes.to_i)
      changes << "Delayed ~#{delay} min"
    end

    if status.status == "cancelled" && reservation.flight_status != "cancelled"
      changes << "Cancelled"
    end

    reservation.update_columns(
      flight_status: status.status,
      gate: status.gate,
      terminal: status.terminal,
      departure_delay_minutes: status.departure_delay_minutes,
      flight_checked_at: Time.current
    )

    NotificationDispatcher.flight_status_changed(reservation, changes) if changes.any?
  end
end
