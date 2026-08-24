class ContactMailer < ApplicationMailer
  # Fan a public contact-form message out to every admin. Reply-To is the
  # visitor so an admin can answer straight from their inbox.
  def new_message(message)
    @message = message
    recipients = User.where(admin: true).pluck(:email)
    return if recipients.empty?

    mail(to: recipients, reply_to: message.email,
         subject: "[Wanderply contact] #{message.display_name}")
  end

  # An admin's answer from /admin/contact_messages. Sent from noreply with the
  # admin as Reply-To so the visitor's follow-up lands in the admin's inbox
  # (wanderply.com has no inbound mail).
  def reply(message, body, admin)
    @message = message
    @body = body
    @admin = admin
    mail(to: message.email, reply_to: admin.email,
         subject: "Re: your message to Wanderply")
  end
end
