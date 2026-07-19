module Admin
  class SupportTicketsController < BaseController
    before_action :set_ticket, only: %i[show reply resolve]

    def index
      @status = params[:status].presence_in(SupportTicket::STATUSES)
      scope = SupportTicket.kept
      scope = scope.where(status: @status) if @status
      # Escalated first (they need a human), then most-recently-active.
      @tickets = scope.order(Arel.sql("CASE WHEN status = 'escalated' THEN 0 ELSE 1 END"))
                      .order(Arel.sql("COALESCE(last_activity_at, created_at) DESC"))
      @counts = SupportTicket.kept.group(:status).count
    end

    def show
      @messages = @ticket.support_messages.ordered
    end

    # Send an admin reply (usually the edited AI draft) to the customer.
    def reply
      body = params.require(:support_message).permit(:body)[:body].to_s.strip
      if body.blank?
        redirect_to admin_support_ticket_path(@ticket), alert: "Reply was empty." and return
      end

      @ticket.transaction do
        @ticket.support_messages.create!(role: "admin", body: body, author: current_user)
        @ticket.update!(status: "ai_answered", admin_draft: nil, escalation_reason: nil, last_activity_at: Time.current)
      end
      NotificationDispatcher.support_answered(@ticket, kind: "support_reply")
      redirect_to admin_support_ticket_path(@ticket), notice: "Reply sent to #{@ticket.user.display_name}."
    end

    def resolve
      @ticket.update!(status: "resolved", last_activity_at: Time.current)
      redirect_to admin_support_ticket_path(@ticket), notice: "Marked resolved."
    end

    private

    def set_ticket
      @ticket = SupportTicket.kept.find(params[:id])
    end
  end
end
