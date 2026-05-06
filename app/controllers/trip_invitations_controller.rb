class TripInvitationsController < ApplicationController
  before_action :set_trip

  # DELETE /trips/:trip_id/invitations/:id
  def destroy
    authorize @trip, :share?
    invitation = @trip.invitations.find(params[:id])
    invitation.discard!
    redirect_to @trip, notice: "Invitation to #{invitation.email} revoked."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end
end
