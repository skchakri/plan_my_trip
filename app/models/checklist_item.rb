class ChecklistItem < ApplicationRecord
  SCOPES = %w[before_trip day activity].freeze
  SCOPE_LABELS = {
    "before_trip" => "Before trip",
    "day"         => "By day",
    "activity"    => "By activity"
  }.freeze

  belongs_to :trip

  validates :title, presence: true
  validates :scope, inclusion: { in: SCOPES }
  validate  :scope_label_present

  scope :ordered,     -> { order(scope: :asc, day_label: :asc, activity_label: :asc, position: :asc, created_at: :asc) }
  scope :before_trip, -> { where(scope: "before_trip") }
  scope :for_day,     -> { where(scope: "day") }
  scope :for_activity, -> { where(scope: "activity") }
  scope :packed,      -> { where(packed: true) }
  scope :unpacked,    -> { where(packed: false) }

  def scope_label
    SCOPE_LABELS[scope] || scope.humanize
  end

  # Section header for grouping in the UI
  def section_key
    case scope
    when "before_trip" then category.presence || "General"
    when "day"         then day_label.presence || "Unscheduled day"
    when "activity"    then activity_label.presence || "Unscheduled activity"
    end
  end

  private

  def scope_label_present
    case scope
    when "day"      then errors.add(:day_label, "is required for a day-scoped item")     if day_label.blank?
    when "activity" then errors.add(:activity_label, "is required for an activity-scoped item") if activity_label.blank?
    end
  end
end
