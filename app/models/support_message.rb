# One message in a support ticket thread. `role` is who wrote it:
#   user      — the person who opened the ticket
#   assistant — the AI (author is nil)
#   admin     — a human operator (author is the admin User)
class SupportMessage < ApplicationRecord
  ROLES = %w[user assistant admin].freeze

  belongs_to :support_ticket, inverse_of: :support_messages
  belongs_to :author, class_name: "User", optional: true

  validates :role, inclusion: { in: ROLES }
  validates :body, presence: true

  scope :ordered, -> { order(:created_at) }

  def from_user? = role == "user"
  def from_ai?   = role == "assistant"
  def from_admin? = role == "admin"
end
