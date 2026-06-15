class TripSharesMailer < ApplicationMailer
  default from: "Plan My Trip <noreply@planmytrip.local>"

  # Sent when a trip is shared with an *existing* account — they get instant
  # in-app access, so this is the email that tells them it happened (new-account
  # invitees get TripInvitationsMailer#invite instead).
  def shared(membership, inviter)
    @membership = membership
    @trip = membership.trip
    @inviter = inviter
    @user = membership.user
    @url = trip_url(@trip)

    mail(
      to: @user.email,
      subject: "#{@inviter.display_name} shared “#{@trip.title}” with you"
    )
  end
end
