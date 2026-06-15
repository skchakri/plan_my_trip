class ActivitiesController < ApplicationController
  before_action :set_trip
  before_action :set_activity, only: %i[update destroy move]

  def create
    authorize @trip, :update?
    day = @trip.trip_days.find(params.require(:trip_day_id))
    day.activities.create!(
      activity_params.merge(position: (day.activities.maximum(:position) || -1) + 1)
    )
    sync_and_redirect "Stop added."
  end

  def update
    authorize @trip, :update?
    @activity.update!(activity_params)
    sync_and_redirect "Stop updated."
  end

  def destroy
    authorize @trip, :update?
    @activity.destroy
    sync_and_redirect "Stop removed."
  end

  # Reorder within the day by swapping with the adjacent stop.
  def move
    authorize @trip, :update?
    stops = @activity.trip_day.activities.to_a
    i = stops.index(@activity)
    j = params[:direction] == "up" ? i - 1 : i + 1
    if i && j.between?(0, stops.size - 1)
      stops[i], stops[j] = stops[j], stops[i]
      stops.each_with_index { |s, idx| s.update_column(:position, idx) }
    end
    sync_and_redirect "Stop reordered."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def set_activity
    @activity = Activity.joins(:trip_day).where(trip_days: { trip_id: @trip.id }).find(params[:id])
  end

  def activity_params
    params.fetch(:activity, {}).permit(:title, :time_label, :location_name, :address, :notes, :famous_for)
  end

  def sync_and_redirect(notice)
    Trips::BodySync.call(@trip)
    redirect_to edit_plan_trip_path(@trip), notice: notice
  end
end
