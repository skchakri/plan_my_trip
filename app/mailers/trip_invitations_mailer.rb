class TripInvitationsMailer < ApplicationMailer
  default from: "Plan My Trip <noreply@planmytrip.local>"

  def invite(invitation)
    @invitation = invitation
    @trip = invitation.trip
    @inviter = invitation.inviter
    @url = invitation_url(@invitation.token)

    mail(
      to: @invitation.email,
      subject: "#{@inviter.display_name} shared a trip with you on Plan My Trip"
    )
  end
end
