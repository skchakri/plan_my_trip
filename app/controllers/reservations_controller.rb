class ReservationsController < ApplicationController
  before_action :set_trip

  # DELETE /trips/:trip_id/reservations/:id — soft-delete a parsed-in reservation.
  def destroy
    reservation = @trip.reservations.find(params[:id])
    authorize reservation
    reservation.discard
    redirect_to @trip, notice: "Removed #{reservation.headline}."
  end

  # POST /trips/:trip_id/reservations/:id/retry — re-run the AI parse for a
  # reservation that failed (e.g. a transient rate-limit or malformed HTML).
  # The raw email is still stored, so we just reset the shell to "parsing" and
  # re-enqueue; the trip page morphs in the result via the existing broadcast.
  def retry
    reservation = @trip.reservations.find(params[:id])
    authorize reservation

    unless reservation.failed? && reservation.raw_email.present?
      return redirect_to @trip, alert: "This reservation can't be re-parsed."
    end

    reservation.update!(status: "parsing")
    ParseReservationJob.perform_later(reservation.id)
    redirect_to @trip, notice: "Re-reading that confirmation…"
  end

  private

  # Trip.kept blocks reservation actions on a discarded (archived) trip.
  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end
end
