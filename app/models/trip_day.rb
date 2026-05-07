class TripDay < ApplicationRecord
  ACCENTS = %w[blue gold teal pink violet emerald rose].freeze

  belongs_to :trip
  has_many :activities, -> { order(position: :asc, created_at: :asc) }, dependent: :destroy

  validates :title, :label, presence: true
  validates :accent, inclusion: { in: ACCENTS }

  scope :ordered, -> { order(position: :asc, date: :asc, created_at: :asc) }

  def checklist_items
    trip.checklist_items.where(scope: "day", day_label: label)
  end

  def packed_count
    checklist_items.where(packed: true).count
  end
end
