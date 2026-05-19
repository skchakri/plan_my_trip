# In-progress trip-creation state for the multi-step wizard. One row per
# user — the wizard upserts. Persisted instead of stored in the cookie
# session so:
#   - draft survives Rails session-store changes / cookie eviction
#   - draft survives across devices for the same logged-in user
#   - we can sweep abandoned drafts and audit funnel completion
#
# Auto-expires after WIZARD_TTL of inactivity; DraftTripSweeper deletes
# rows past expires_at.
class DraftTrip < ApplicationRecord
  WIZARD_TTL = 14.days

  belongs_to :user

  validates :user_id, uniqueness: true
  validates :expires_at, presence: true

  scope :live,    -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where(expires_at: ..Time.current) }

  before_validation :ensure_expires_at

  def self.for(user)
    where(user_id: user.id).live.first
  end

  def self.fetch_or_build(user)
    rec = where(user_id: user.id).first_or_initialize
    rec.expires_at = WIZARD_TTL.from_now if rec.new_record? || rec.expires_at.nil? || rec.expires_at.past?
    rec
  end

  # Hash-like accessors so the existing wizard code that does
  # `@draft["destination"]` keeps working without controller-wide changes.
  # AR attribute names fall through to super so internal callers (e.g. the
  # belongs_to writer's `self["user_id"] = ...`) still hit the column.
  def [](key)
    if self.class.column_names.include?(key.to_s)
      super
    else
      payload[key.to_s]
    end
  end

  def []=(key, value)
    if self.class.column_names.include?(key.to_s)
      super
    else
      payload[key.to_s] = value
    end
  end

  def merge(other)
    payload.merge(other.deep_stringify_keys)
  end

  def merge!(other)
    payload.merge!(other.deep_stringify_keys)
  end

  def key?(name)
    payload.key?(name.to_s)
  end

  def delete(key)
    payload.delete(key.to_s)
  end

  def to_h
    payload
  end

  def save_step!(step_name)
    self.step         = step_name.to_s
    self.last_step_at = Time.current
    self.expires_at   = WIZARD_TTL.from_now
    save!
  end

  private

  def ensure_expires_at
    self.expires_at ||= WIZARD_TTL.from_now
  end
end
