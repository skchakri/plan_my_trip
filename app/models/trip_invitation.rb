class TripInvitation < ApplicationRecord
  include Discard::Model

  belongs_to :trip
  belongs_to :inviter, class_name: "User"

  before_validation :normalize_email
  before_validation :ensure_token, on: :create

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true

  scope :pending, -> { kept.where(accepted_at: nil, declined_at: nil) }

  def pending?
    accepted_at.nil? && declined_at.nil? && !discarded?
  end

  def accepted?
    accepted_at.present?
  end

  def declined?
    declined_at.present?
  end

  def matches_user?(user)
    return false if user.blank?
    user.email.to_s.casecmp(email.to_s).zero?
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end
end
