class ChecklistItem < ApplicationRecord
  belongs_to :trip

  validates :title, presence: true

  scope :ordered, -> { order(category: :asc, position: :asc, created_at: :asc) }
  scope :packed, -> { where(packed: true) }
  scope :unpacked, -> { where(packed: false) }
end
