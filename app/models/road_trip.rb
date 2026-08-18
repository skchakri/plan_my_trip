# A curated, SEO-indexed road-trip guide rendered at /road-trips/:slug. Content
# is hand-authored (or drafted offline via lib/tasks/road_trips.rake) and stored
# here in full — the public page renders it with ZERO per-request AI calls
# (these pages are crawled heavily; see the cost-first BuildQuota ethos).
#
# Decoupled from user Trips on purpose: stable editorial slugs, public exposure,
# no auth/Pundit entanglement.
class RoadTrip < ApplicationRecord
  include Discard::Model

  STATUSES = %w[draft published archived].freeze

  validates :origin, :destination, :title, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase letters, numbers and hyphens" }
  validates :status, inclusion: { in: STATUSES }

  scope :published, -> { kept.where(status: "published") }
  # Instant-index on publish/edit of a public guide (no-op unless INDEXNOW_KEY is set).
  after_commit :ping_index_now, on: %i[create update], if: :published?
  scope :ordered,   -> { order(:position, :title) }

  before_validation :generate_slug, if: -> { slug.blank? && origin.present? && destination.present? }

  def to_param = slug

  def public_url = Rails.application.routes.url_helpers.road_trip_url(slug, host: IndexNow::HOST, protocol: "https")

  def published? = status == "published"

  # ── JSONB content, always coerced to an array of hashes with string keys ──
  def stops     = Array(self[:stops])
  def itinerary = Array(self[:itinerary])
  def faqs      = Array(self[:faqs])

  # Short "SF → Las Vegas" corridor label.
  def corridor = "#{origin} → #{destination}"

  private

  def generate_slug
    self.slug = "#{origin}-to-#{destination}".parameterize
  end

  def ping_index_now
    IndexNowPingJob.perform_later([ public_url ])
  end
end
