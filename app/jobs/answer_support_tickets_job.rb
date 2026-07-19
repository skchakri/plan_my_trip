# Hourly recurring entry point (config/recurring.yml). Fans out one
# AnswerSupportTicketJob per open ticket so each AI call runs independently
# across Solid Queue workers. PER_RUN_LIMIT bounds paid AI spend per pass —
# the account-level companion to BuildQuota's trip-build caps.
class AnswerSupportTicketsJob < ApplicationJob
  queue_as :default

  PER_RUN_LIMIT = 50

  def perform
    SupportTicket.needs_ai.order(:last_activity_at).limit(PER_RUN_LIMIT).find_each do |ticket|
      AnswerSupportTicketJob.perform_later(ticket.id)
    end
  end
end
