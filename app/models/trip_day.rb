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
  def weather_anchor
    located = activities.select { |a| a.latitude.present? && a.longitude.present? }
    return nil if located.empty?

    located.find do |a|
      a.group_label.to_s.strip.casecmp("lodging").zero? || a.title.to_s.match?(/check[- ]?in/i)
    end || located[located.size / 2]
  end

  def representative_coords
    anchor = weather_anchor
    anchor && [ anchor.latitude.to_f, anchor.longitude.to_f ]
  end

  # Human label for the anchor, so a multi-city trip's weather strip can say
  # which place each day's forecast belongs to.
  def representative_place
    anchor = weather_anchor
    return nil unless anchor
    (anchor.location_name.presence || anchor.title.to_s).strip.presence
  end

  def packed_count
    checklist_items.where(packed: true).count
  end
end
