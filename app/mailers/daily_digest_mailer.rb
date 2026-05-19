class DailyDigestMailer < ApplicationMailer
  default from: "Plan My Trip <noreply@planmytrip.app>"

  # Renders only if the user has 1+ unread notifications in the last 24h
  # AND hasn't opted out. The job that calls this is responsible for
  # passing the right user; we still defensive-check inside the mailer.
  def daily(user, since: 24.hours.ago)
    @user = user
    @notifications = user.notifications_received.unread.where("created_at >= ?", since).recent.limit(20)
    return self.message = ActionMailer::Base::NullMail.new if @user.digest_optout_at.present? || @notifications.empty?

    @unread_total = @notifications.size
    mail to: user.email, subject: digest_subject
  end

  private

  def digest_subject
    "#{@unread_total} #{'update'.pluralize(@unread_total)} on your trips"
  end
end
