class Comment < ApplicationRecord
  include Discard::Model

  belongs_to :activity
  belongs_to :author, class_name: "User"
  has_one :trip_day, through: :activity
  has_one :trip,     through: :trip_day

  validates :body, presence: true, length: { maximum: 4_000 }

  scope :ordered, -> { order(created_at: :asc) }

  def edited?
    updated_at - created_at > 5
  end
end
