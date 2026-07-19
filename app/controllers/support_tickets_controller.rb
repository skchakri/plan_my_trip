class SupportTicketsController < ApplicationController
  before_action :set_ticket, only: %i[show reply]

  def index
    @tickets = policy_scope(SupportTicket).recent
  end

  def show
    @messages = @ticket.support_messages.ordered
  end

  def new
    @ticket = current_user.support_tickets.new
    authorize @ticket
  end

  def create
    @ticket = current_user.support_tickets.new(ticket_params.except(:body))
    authorize @ticket
    @ticket.status = "open"

    if @ticket.save
      @ticket.support_messages.create!(role: "user", body: ticket_params[:body], author: current_user)
      redirect_to support_ticket_path(@ticket), notice: "Thanks — we got your question. We usually reply within an hour."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def reply
    authorize @ticket, :reply?
    body = params.require(:support_message).permit(:body)[:body]
    if body.to_s.strip.present?
      @ticket.support_messages.create!(role: "user", body: body, author: current_user)
      @ticket.reopen!
      redirect_to support_ticket_path(@ticket), notice: "Reply sent — we'll get back to you."
    else
      redirect_to support_ticket_path(@ticket), alert: "Your reply was empty."
    end
  end

  private

  def set_ticket
    @ticket = current_user.support_tickets.kept.find(params[:id])
  end

  def ticket_params
    params.require(:support_ticket).permit(:subject, :category, :body)
  end
end
