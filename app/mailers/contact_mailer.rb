class ContactMailer < ApplicationMailer
  # Fan a public contact-form message out to every admin. Reply-To is the
  # visitor so an admin can answer straight from their inbox.
  def new_message(message)
    @message = message
    recipients = User.where(admin: true).pluck(:email)
    return if recipients.empty?

    mail(to: recipients, reply_to: message[:email], subject: "[Wanderply contact] #{message[:name].presence || message[:email]}")
  end
end
