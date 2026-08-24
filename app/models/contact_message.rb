# A message sent through the public /contact form. Every submission is stored
# (spam included, flagged) so admins can triage at /admin/contact_messages
# instead of relying on their personal inbox; non-spam messages are also
# mailed to every admin (ContactMailer#new_message).
class ContactMessage < ApplicationRecord
  belongs_to :user, optional: true

  attr_accessor :honeypot # must stay blank; bots fill every field

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :body, presence: true, length: { minimum: 10, maximum: 4000 }
  validates :name, length: { maximum: 120 }

  scope :recent, -> { order(created_at: :desc) }
  scope :ham,    -> { where(spam: false) }
  scope :unread, -> { ham.where(read_at: nil) }

  before_validation :normalize
  before_create :classify_spam

  def to_h = { name: name.to_s.strip, email: email.to_s.strip, body: body.to_s.strip }

  def read?    = read_at.present?
  def replied? = replied_at.present?
  def display_name = name.presence || email

  def mark_read!  = read? || update_column(:read_at, Time.current)
  def mark_spam!(flag, reason: "admin")
    update!(spam: flag, spam_reason: flag ? reason : nil)
  end

  # Cheap heuristics for the form-spam bots that get past the honeypot
  # (random name + unrelated gmail address + a boilerplate "send me your
  # price list" in Cyrillic). Flagged messages are stored but not mailed.
  def self.spam_reason_for(name:, email:, body:, honeypot: nil)
    return "honeypot filled" if honeypot.present?

    text = body.to_s
    reasons = []
    reasons << "non-Latin script" if text.match?(/[\p{Cyrillic}\p{Han}\p{Arabic}]{4,}/)
    reasons << "links" if text.scan(%r{https?://}i).size >= 2
    reasons << "price-list bait" if text.match?(/\b(price ?list|прайс|pricelist)\b/i)
    reasons << "name/email mismatch" if suspicious_name?(name, email)
    # A single mismatch alone is too weak — real people use nicknames.
    reasons.delete("name/email mismatch") if reasons.size == 1
    reasons.presence&.join(", ")
  end

  def self.suspicious_name?(name, email)
    n = name.to_s.downcase.gsub(/[^a-z]/, "")
    local = email.to_s.split("@").first.to_s.downcase.gsub(/[^a-z]/, "")
    return false if n.length < 6 || local.length < 4
    !(local.include?(n[0, 4]) || n.include?(local[0, 4]))
  end

  private

  def normalize
    self.email = email.to_s.strip.downcase
    self.name  = name.to_s.strip.presence
    self.body  = body.to_s.strip
  end

  def classify_spam
    return if spam? # honeypot path sets it explicitly
    reason = self.class.spam_reason_for(name: name, email: email, body: body)
    if reason
      self.spam = true
      self.spam_reason = reason
    end
  end
end
