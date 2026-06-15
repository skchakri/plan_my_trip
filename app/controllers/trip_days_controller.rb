class TripDaysController < ApplicationController
  before_action :set_trip
  before_action :set_day, only: %i[update destroy move]

  def create
    authorize @trip, :update?
    count = @trip.trip_days.count
    label = day_params[:label].presence || "Day #{count + 1}"
    @trip.trip_days.create!(
      label: label,
      title: day_params[:title].presence || label,
      date: day_params[:date].presence,
      summary: day_params[:summary],
      position: (@trip.trip_days.maximum(:position) || -1) + 1,
      accent: TripDay::ACCENTS[count % TripDay::ACCENTS.size]
    )
    sync_and_redirect "Day added."
  end

  def update
    authorize @trip, :update?
    @day.update!(day_params)
    sync_and_redirect "Day updated."
  end

  def destroy
    authorize @trip, :update?
    @day.destroy
    sync_and_redirect "Day removed."
  end

  # Reorder by swapping with the adjacent day, then normalising positions.
  def move
    authorize @trip, :update?
    days = @trip.trip_days.ordered.to_a
    i = days.index(@day)
    j = params[:direction] == "up" ? i - 1 : i + 1
    if i && j.between?(0, days.size - 1)
      days[i], days[j] = days[j], days[i]
      days.each_with_index { |d, idx| d.update_column(:position, idx) }
    end
    sync_and_redirect "Day reordered."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def set_day
    @day = @trip.trip_days.find(params[:id])
  end

  def day_params
    params.fetch(:trip_day, {}).permit(:label, :title, :date, :summary)
  end

  def sync_and_redirect(notice)
    Trips::BodySync.call(@trip)
    redirect_to edit_plan_trip_path(@trip), notice: notice
  end
end
