# Answers one support ticket. Confident, safe answers are posted straight to
# the customer (status → ai_answered) and they're notified. Anything the AI
# flags for a human is drafted into the ticket (admin_draft) and escalated
# (status → escalated) with a notification to every admin — the user is NOT
# messaged until an admin reviews and sends.
class AnswerSupportTicketJob < ApplicationJob
  queue_as :default

  def perform(ticket_id)
    ticket = SupportTicket.kept.find_by(id: ticket_id)
    # Re-check status: a user reply or admin action between enqueue and run
    # could have moved it off `open`. Idempotent against double-enqueue.
    return unless ticket&.needs_ai_answer?

    ticket.increment!(:ai_attempts)

    decision = SupportAnswerer.call(ticket)
    return if decision.nil? # AI error — leave open for the next hourly pass

    if decision.needs_human?
      escalate(ticket, decision)
    else
      auto_answer(ticket, decision)
    end
  end

  private

  def auto_answer(ticket, decision)
    ticket.transaction do
      ticket.support_messages.create!(role: "assistant", body: decision.reply)
      ticket.update!(status: "ai_answered", admin_draft: nil, escalation_reason: nil, last_activity_at: Time.current)
    end
    NotificationDispatcher.support_answered(ticket)
  end

  def escalate(ticket, decision)
    ticket.update!(
      status:            "escalated",
      admin_draft:       decision.reply,
      escalation_reason: decision.reason.presence,
      last_activity_at:  Time.current
    )
    NotificationDispatcher.support_escalated(ticket)
  end
end
