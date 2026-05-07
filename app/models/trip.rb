class Trip < ApplicationRecord
  include Discard::Model

  belongs_to :owner, class_name: "User"
  has_many :trip_memberships, dependent: :destroy
  has_many :members, through: :trip_memberships, source: :user
  has_many :trails, dependent: :destroy
  accepts_nested_attributes_for :trails, allow_destroy: true, reject_if: :all_blank
  has_many :invitations, class_name: "TripInvitation", dependent: :destroy
  has_many :checklist_items, dependent: :destroy
  has_many :trip_days, -> { ordered }, dependent: :destroy

  validates :title, presence: true
  validate :end_after_start

  after_create :ensure_owner_membership

  scope :ordered, -> { order(start_date: :asc, created_at: :desc) }

  def shared_with?(user)
    return false if user.blank?
    trip_memberships.where(user_id: user.id).exists?
  end

  def title_for(user)
    membership = trip_memberships.find_by(user_id: user&.id)
    membership&.custom_title.presence || title
  end

  def nights
    return nil if start_date.blank? || end_date.blank?
    (end_date - start_date).to_i
  end

  def days
    n = nights
    n.nil? ? nil : n + 1
  end

  def member_count
    trip_memberships.count
  end

  private

  def end_after_start
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "must be on or after start date") if end_date < start_date
  end

  def ensure_owner_membership
    trip_memberships.find_or_create_by!(user: owner) do |m|
      m.role = "owner"
      m.accepted_at = Time.current
    end
  end
end
