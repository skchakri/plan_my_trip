class TripSharesController < ApplicationController
  before_action :set_trip

  def new
    authorize @trip, :share?
  end

  def create
    authorize @trip, :share?
    email = params.require(:email).to_s.strip.downcase
    user = User.find_by("LOWER(email) = ?", email)

    if user.nil?
      redirect_to new_trip_share_path(@trip), alert: "No user found with email #{email}. They need to sign up first."
      return
    end

    if user == current_user
      redirect_to new_trip_share_path(@trip), alert: "You already own this trip."
      return
    end

    membership = @trip.trip_memberships.find_or_initialize_by(user: user)
    if membership.persisted?
      redirect_to @trip, notice: "#{user.display_name} already has access."
    else
      membership.role = "member"
      membership.accepted_at = Time.current
      membership.save!
      redirect_to @trip, notice: "Shared with #{user.display_name}. It's now in their trips."
    end
  end

  def destroy
    authorize @trip, :share?
    membership = @trip.trip_memberships.find(params[:id])
    if membership.owner?
      redirect_to @trip, alert: "Can't remove the owner."
    else
      membership.destroy
      redirect_to @trip, notice: "Removed access for #{membership.user.display_name}."
    end
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end
end
