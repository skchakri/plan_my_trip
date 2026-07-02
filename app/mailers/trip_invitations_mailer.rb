class TripInvitationsMailer < ApplicationMailer
  default from: "Wanderply <noreply@wanderply.com>"

  def invite(invitation)
    @invitation = invitation
    @trip = invitation.trip
    @inviter = invitation.inviter
    @url = invitation_url(@invitation.token)

    mail(
      to: @invitation.email,
      subject: "#{@inviter.display_name} shared a trip with you on Wanderply"
    )
  end
end
