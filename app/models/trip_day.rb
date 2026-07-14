class TripDay < ApplicationRecord
  ACCENTS = %w[blue gold teal pink violet emerald rose].freeze

  belongs_to :trip
  has_many :activities, -> { order(position: :asc, created_at: :asc) }, dependent: :destroy
  has_many :suggestions, -> { ranked }, dependent: :destroy

  validates :title, :label, presence: true
  validates :accent, inclusion: { in: ACCENTS }

  scope :ordered, -> { order(position: :asc, date: :asc, created_at: :asc) }

  def checklist_items
    trip.checklist_items.kept.where(scope: "day", day_label: label)
  end

  # Where this day "happens", for day-local weather: prefer the lodging stop
  # (that's where the evening is spent), else the middle located activity —
  # on a driving day the midpoint beats the departure city. nil when no
  # activity has coordinates (callers fall back to the trip destination).
  def representative_coords
    located = activities.select { |a| a.latitude.present? && a.longitude.present? }
    return nil if located.empty?

    lodging = located.find do |a|
      a.group_label.to_s.strip.casecmp("lodging").zero? || a.title.to_s.match?(/check[- ]?in/i)
    end
    pick = lodging || located[located.size / 2]
    [ pick.latitude.to_f, pick.longitude.to_f ]
  end

  def packed_count
    checklist_items.where(packed: true).count
  end
end
