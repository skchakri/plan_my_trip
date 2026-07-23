# Every `deliver_later` runs through this job.
#
# Action Mailer's default delivery job descends from ActiveJob::Base, NOT from
# ApplicationJob — so its catch-all `rescue_from` never applied to outbound
# mail. A rejected send (SES suppression, an unverified identity, a throttle)
# failed silently: the row landed in solid_queue_failed_executions and nowhere a
# human looks, while the UI had already said "Invitation sent". Now a failed
# delivery is reported like any other error and shows up in /admin.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  rescue_from(StandardError) do |error|
    mailer, action = arguments[0], arguments[1]
    Rails.error.report(
      error,
      severity: :error,
      context: {
        job:        self.class.name,
        mailer:     "#{mailer}##{action}",
        executions: executions
      },
      handled: false
    )
    raise # Solid Queue still marks it failed so the retry policy applies.
  end
end
