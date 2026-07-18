class Notification < ApplicationRecord
  KINDS = %w[comment_posted comment_mention trip_share_accepted invitation_pending flight_status].freeze

  belongs_to :recipient, class_name: "User"
  belongs_to :actor,     class_name: "User", optional: true
  belongs_to :subject,   polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def unread? = read_at.nil?

  def mark_read!
    update!(read_at: Time.current) if unread?
  end
end
