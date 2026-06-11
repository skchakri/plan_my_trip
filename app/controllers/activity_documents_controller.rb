class ActivityDocumentsController < ApplicationController
  include AttachmentFiltering
  before_action :set_trip
  before_action :set_activity

  # POST /trips/:trip_id/activities/:activity_id/documents
  def create
    authorize @trip, :show?
    files = params.require(:activity).permit(documents: []).fetch(:documents, []).reject(&:blank?)
    if files.empty?
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  alert: "Pick at least one file to upload." and return
    end

    rejected = []
    files = filter_allowed_files(files, Activity::DOCUMENT_CONTENT_TYPES, rejected)
    if files.empty?
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  alert: "Unsupported file type: #{rejected.to_sentence}. Use PDF, image, or plain-text files." and return
    end

    @activity.documents.attach(files)
    if @activity.valid?
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  notice: "Attached #{files.size} #{'document'.pluralize(files.size)} to #{@activity.title}."
    else
      # Active Storage saved the attachments eagerly, so purge anything that
      # tripped our size validation.
      @activity.documents.each do |doc|
        doc.purge if doc.byte_size && doc.byte_size > Activity::MAX_DOCUMENT_BYTES
      end
      redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                  alert: @activity.errors.full_messages.to_sentence
    end
  end

  # DELETE /trips/:trip_id/activities/:activity_id/documents/:id
  def destroy
    authorize @trip, :update?
    attachment = @activity.documents.find(params[:id])
    name = attachment.filename.to_s
    attachment.purge
    redirect_to plan_trip_path(@trip, anchor: "day-#{@activity.trip_day_id}"),
                notice: "Removed #{name}."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def set_activity
    @activity = Activity.joins(:trip_day).where(trip_days: { trip_id: @trip.id }).find(params[:activity_id])
  end
end
