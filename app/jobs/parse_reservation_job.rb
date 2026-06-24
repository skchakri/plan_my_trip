# Runs the (network-bound) reservation extraction off the ingress request: the
# ReservationsMailbox persists a "parsing" Reservation shell and enqueues this,
# which AI-parses the email body into structured fields and broadcasts a Turbo
# refresh so an open trip page morphs in the finished reservation.
class ParseReservationJob < ApplicationJob
  queue_as :default

  def perform(reservation_id, subject: nil)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation&.parsing?

    Reservations::Parser.call(reservation, subject: subject)
  rescue StandardError => e
    ErrorTracker.report(e, source: "ParseReservationJob", context: { reservation_id: reservation_id })
    reservation&.update_columns(status: "failed", updated_at: Time.current)
  ensure
    # Refresh the trip page (subscribed via turbo_stream_from) into the new row.
    reservation&.trip&.broadcast_refresh_to(reservation.trip)
  end
end
