class TripDocumentsController < ApplicationController
  before_action :set_trip

  def create
    authorize @trip, :show?
    files = params.require(:trip).permit(documents: []).fetch(:documents, []).reject(&:blank?)
    if files.empty?
      redirect_to @trip, alert: "Pick at least one file." and return
    end
    @trip.documents.attach(files)
    redirect_to @trip, notice: "Attached #{files.size} #{'document'.pluralize(files.size)} to the trip."
  end

  def destroy
    authorize @trip, :update?
    attachment = @trip.documents.find(params[:id])
    name = attachment.filename.to_s
    attachment.purge
    redirect_to @trip, notice: "Removed #{name}."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end
end
