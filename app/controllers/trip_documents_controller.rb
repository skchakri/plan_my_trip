class TripDocumentsController < ApplicationController
  include AttachmentFiltering
  before_action :set_trip

  def create
    authorize @trip, :show?
    # Tolerate a missing `trip` key: submitting the upload form with no file
    # part (e.g. the Android WebView shell) would otherwise raise
    # ActionController::ParameterMissing -> a bare 400 page, since the form
    # runs with turbo:false and navigates straight to this POST target.
    files = params.fetch(:trip, ActionController::Parameters.new)
                  .permit(documents: []).fetch(:documents, []).reject(&:blank?)
    if files.empty?
      redirect_to @trip, alert: "Pick at least one file." and return
    end
    rejected = []
    files = filter_allowed_files(files, Trip::DOCUMENT_CONTENT_TYPES, rejected)
    if files.empty?
      redirect_to @trip, alert: "Unsupported file type: #{rejected.to_sentence}. Use PDF, image, or plain-text files." and return
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
