class InvitationsController < ApplicationController
  # Don't force sign-in here — that's exactly the point of an invitation link.
  skip_before_action :authenticate_user!, only: %i[show]
  before_action :set_invitation
  before_action :ensure_invitation_active

  # GET /invitations/:token
  # Routes the recipient to the right place:
  # - signed in as the invited email   → show accept/decline page
  # - signed in as someone else        → tell them to sign out
  # - not signed in, account exists    → save token in session, send to login
  # - not signed in, account missing   → save token in session, send to signup with email pre-filled
  def show
    if user_signed_in?
      if @invitation.matches_user?(current_user)
        # Render accept/decline page (default :show view)
      else
        sign_out current_user
        session[:invitation_token] = @invitation.token
        redirect_to new_user_session_path, alert: "Sign in as #{@invitation.email} to accept this invitation."
      end
    elsif (existing_user = User.find_by("LOWER(email) = ?", @invitation.email))
      session[:invitation_token] = @invitation.token
      redirect_to new_user_session_path, notice: "Sign in as #{existing_user.email} to accept your trip invitation."
    else
      session[:invitation_token] = @invitation.token
      session[:invitation_email] = @invitation.email
      redirect_to new_user_registration_path, notice: "Create an account to accept your trip invitation."
    end
  end

  # POST /invitations/:token/accept
  def accept
    return reject_mismatch unless @invitation.matches_user?(current_user)

    membership = @invitation.trip.trip_memberships.find_or_initialize_by(user: current_user)
    membership.role ||= "member"
    membership.accepted_at ||= Time.current
    new_membership = membership.new_record?
    membership.save!

    @invitation.update!(accepted_at: Time.current)
    NotificationDispatcher.trip_share_accepted(membership) if new_membership

    redirect_to @invitation.trip, notice: "Added \"#{@invitation.trip.title}\" to your trips."
  end

  # DELETE /invitations/:token
  def decline
    return reject_mismatch unless @invitation.matches_user?(current_user)

    @invitation.update!(declined_at: Time.current)
    redirect_to root_path, notice: "Invitation declined."
  end

  private

  def set_invitation
    @invitation = TripInvitation.find_by(token: params[:token])
  end

  def ensure_invitation_active
    if @invitation.nil? || !@invitation.pending?
      redirect_to root_path, alert: "This invitation is no longer valid."
    end
  end

  def reject_mismatch
    redirect_to root_path, alert: "This invitation was sent to #{@invitation.email}. Sign in with that email to accept."
  end
end
