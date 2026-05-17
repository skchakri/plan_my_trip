class BookingClaimsController < ApplicationController
  before_action :set_trip
  before_action :authorize_update

  # POST /trips/:trip_id/booking_claims
  # Create or update the single claim for this trip + kind in one shot.
  def create
    kind = params.require(:booking_claim).permit(:kind)[:kind]
    return redirect_to(@trip, alert: "Unknown booking kind.") unless BookingClaim::KINDS.include?(kind)

    claim = @trip.booking_claims.find_or_initialize_by(kind: kind)
    attrs = params.require(:booking_claim).permit(:note, documents: [])
    claim.note = attrs[:note]
    claim.documents.attach(attrs[:documents]) if attrs[:documents].present?
    # If this is a cars claim, keep the legacy transport_mode in sync so the
    # AI checklist + UI hints downstream stay consistent.
    @trip.update(transport_mode: "own_car") if kind == "cars" && @trip.transport_mode.blank?

    if claim.save
      redirect_to @trip, notice: "Marked #{claim.kind_label.downcase} as handled."
    else
      redirect_to @trip, alert: claim.errors.full_messages.to_sentence
    end
  end

  # DELETE /trips/:trip_id/booking_claims/:id
  def destroy
    claim = @trip.booking_claims.find(params[:id])
    kind = claim.kind
    claim.destroy
    @trip.update(transport_mode: nil) if kind == "cars" && @trip.transport_mode == "own_car"
    redirect_to @trip, notice: "Removed your #{BookingClaim::KIND_LABELS[kind].to_s.downcase} claim — booking options restored."
  end

  # DELETE /trips/:trip_id/booking_claims/:id/documents/:doc_id
  def destroy_document
    claim = @trip.booking_claims.find(params[:id])
    doc = claim.documents.find(params[:doc_id])
    fname = doc.filename
    doc.purge_later
    redirect_to @trip, notice: "Removed #{fname}."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def authorize_update
    authorize @trip, :update?
  end
end
