class TripSharesController < ApplicationController
  before_action :set_trip

  def new
    authorize @trip, :share?
  end

  def create
    authorize @trip, :share?
    email = params.require(:email).to_s.strip.downcase

    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      redirect_to(new_trip_share_path(@trip), alert: "Please enter a valid email address.") and return
    end

    if email == current_user.email.downcase
      redirect_to(new_trip_share_path(@trip), alert: "You already own this trip.") and return
    end

    user = User.find_by("LOWER(email) = ?", email)

    if user
      share_with_existing_user(user)
    else
      invite_new_user(email)
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

  def share_with_existing_user(user)
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

  def invite_new_user(email)
    invitation = @trip.invitations.pending.find_by(email: email)
    if invitation
      TripInvitationsMailer.invite(invitation).deliver_later
      redirect_to @trip, notice: "Re-sent invitation to #{email}."
      return
    end

    invitation = @trip.invitations.create!(email: email, inviter: current_user)
    TripInvitationsMailer.invite(invitation).deliver_later
    redirect_to @trip, notice: "Invitation sent to #{email}. They'll be added once they sign up."
  end
end
