class ActivityPhotosController < ApplicationController
  include AttachmentFiltering
  before_action :set_trip
  before_action :set_activity

  # POST /trips/:trip_id/activities/:activity_id/photos
  def create
    authorize @trip, :show?
    files = params.require(:activity).permit(photos: []).fetch(:photos, []).reject(&:blank?)
    if files.empty?
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  alert: "Pick at least one image to upload." and return
    end

    rejected = []
    files = filter_allowed_files(files, Activity::PHOTO_CONTENT_TYPES, rejected)
    if files.empty?
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  alert: "Unsupported file type: #{rejected.to_sentence}. Photos must be PNG, JPEG, WEBP, HEIC, or GIF." and return
    end

    @activity.photos.attach(files)
    if @activity.valid?
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  notice: "Added #{files.size} #{'photo'.pluralize(files.size)} to #{@activity.title}."
    else
      @activity.photos.each do |photo|
        photo.purge if photo.byte_size && photo.byte_size > Activity::MAX_PHOTO_BYTES
      end
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  alert: @activity.errors.full_messages.to_sentence
    end
  end

  # DELETE /trips/:trip_id/activities/:activity_id/photos/:id
  def destroy
    authorize @trip, :update?
    attachment = @activity.photos.find(params[:id])
    attachment.purge
    redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                notice: "Removed photo."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def set_activity
    @activity = Activity.joins(:trip_day).where(trip_days: { trip_id: @trip.id }).find(params[:activity_id])
  end
end
