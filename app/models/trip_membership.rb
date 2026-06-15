class TripMembership < ApplicationRecord
  # owner  — created the trip; full control (share, delete, manage roles).
  # editor — can edit the itinerary/days/activities/checklist, but can't
  #          delete the trip or manage who has access.
  # member — view + collaborate (comments, suggestions, votes, own travelers)
  #          but can't change the plan.
  ROLES = %w[owner editor member].freeze

  belongs_to :trip
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :trip_id }

  scope :owners,  -> { where(role: "owner") }
  scope :editors, -> { where(role: "editor") }
  scope :shared,  -> { where.not(role: "owner") }

  def owner?
    role == "owner"
  end

  def editor?
    role == "editor"
  end

  # Owners and editors may change the plan.
  def can_edit?
    owner? || editor?
  end
end
