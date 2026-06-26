class ReservationsController < ApplicationController
  before_action :set_trip

  # DELETE /trips/:trip_id/reservations/:id — soft-delete a parsed-in reservation.
  def destroy
    reservation = @trip.reservations.find(params[:id])
    authorize reservation
    reservation.discard
    redirect_to @trip, notice: "Removed #{reservation.headline}."
  end

  private

  # Trip.kept blocks reservation actions on a discarded (archived) trip.
  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end
end
