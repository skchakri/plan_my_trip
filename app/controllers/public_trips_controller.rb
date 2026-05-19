class PublicTripsController < ApplicationController
  layout "public"

  # Show is the only public endpoint. Enable/disable/rotate are owner-only
  # under the standard /trips/:id namespace and reuse TripPolicy#share?.
  skip_before_action :authenticate_user!, only: %i[show calendar]

  # GET /s/:token
  def show
    @trip = active_share_trip!
    @days = @trip.trip_days.ordered.includes(:activities)
  rescue ActiveRecord::RecordNotFound
    render :gone, status: :gone
  end

  # GET /s/:token/calendar.ics — same .ics as the auth-gated feed, but
  # gated by an active share token instead of trip_memberships. Returns
  # 410 once the owner revokes.
  def calendar
    trip = active_share_trip!
    send_data TripIcsBuilder.new(trip).to_ics,
              type: "text/calendar; charset=utf-8",
              filename: "#{trip.title.parameterize.presence || 'trip'}.ics",
              disposition: "inline"
  rescue ActiveRecord::RecordNotFound
    head :gone
  end

  # POST /trips/:id/share_link
  def enable
    trip = owned_trip!
    trip.enable_share_link!
    redirect_to trip, notice: "Public link is live. Anyone with the URL can view this trip."
  end

  # DELETE /trips/:id/share_link
  def disable
    trip = owned_trip!
    trip.disable_share_link!
    redirect_to trip, notice: "Public link revoked."
  end

  # POST /trips/:id/share_link_rotate
  def rotate
    trip = owned_trip!
    trip.regenerate_share_token!
    redirect_to trip, notice: "Public link rotated. The old URL no longer works."
  end

  private

  def active_share_trip!
    Trip.kept.where(share_revoked_at: nil).find_by!(share_token: params[:token])
  end

  def owned_trip!
    trip = Trip.kept.find(params[:id])
    authorize trip, :share?
    trip
  end
end
