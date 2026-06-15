class PreTripReminderMailer < ApplicationMailer
  default from: "Plan My Trip <noreply@planmytrip.local>"

  def reminder(trip, user, days_out)
    @trip = trip
    @user = user
    @days_out = days_out
    @url = trip_url(trip)
    @checklist_url = checklist_trip_url(trip)

    subject = case days_out
    when 1 then "“#{trip.title}” starts tomorrow 🎒"
    else "“#{trip.title}” is #{days_out} days away"
    end

    mail(to: user.email, subject: subject)
  end
end
