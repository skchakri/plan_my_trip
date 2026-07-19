# A user's support question and the conversation that answers it. An hourly
# job (AnswerSupportTicketsJob → AnswerSupportTicketJob) has the AI answer
# `open` tickets: confident answers are posted straight to the user
# (status → ai_answered); anything needing a human is drafted into
# `admin_draft` and escalated (status → escalated) for an admin to review.
class SupportTicket < ApplicationRecord
  include Discard::Model

  # open       — awaiting an answer (AI will pick it up), incl. after a user reply
  # ai_answered — the AI (or an admin) has replied to the user
  # escalated  — AI flagged it for a human; admin_draft holds the drafted reply
  # resolved   — closed out by an admin (or the user)
  # closed     — archived
  STATUSES = %w[open ai_answered escalated resolved closed].freeze

  belongs_to :user
  has_many :support_messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :support_ticket

  validates :subject, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }

  scope :needs_ai,   -> { kept.where(status: "open") }
  scope :escalated,  -> { kept.where(status: "escalated") }
  scope :recent,     -> { order(Arel.sql("COALESCE(last_activity_at, created_at) DESC")) }

  before_validation { self.last_activity_at ||= Time.current }

  def needs_ai_answer? = status == "open"

  # Roll the ticket back to `open` when the user adds a new message so the
  # hourly job answers the follow-up.
  def reopen!
    update!(status: "open", last_activity_at: Time.current)
  end
end
