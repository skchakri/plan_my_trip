class TripMembership < ApplicationRecord
  ROLES = %w[owner member].freeze

  belongs_to :trip
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :trip_id }

  scope :owners, -> { where(role: "owner") }
  scope :shared, -> { where(role: "member") }

  def owner?
    role == "owner"
  end
end
