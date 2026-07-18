class Trail < ApplicationRecord
  ALLTRAILS_HOST_RE = /\Ahttps?:\/\/(www\.)?alltrails\.com\//i

  belongs_to :trip

  validates :name, presence: true
  validates :alltrails_url, format: {
    with: ALLTRAILS_HOST_RE,
    message: "must be an alltrails.com URL",
    allow_blank: true
  }

  default_scope -> { order(position: :asc, created_at: :asc) }

  # Geocode the trailhead + look up its elevation off-request. Runs on create
  # and whenever the name changes (a different trail ⇒ stale coords) — on create
  # the name is itself a saved change, so one guarded callback covers both.
  # Best-effort — see Trails::TrailheadEnricher.
  after_commit :enqueue_trailhead_enrichment, on: %i[create update], if: :saved_change_to_name?

  def has_alltrails_link?
    alltrails_url.present?
  end

  def trailhead_located?
    trailhead_lat.present? && trailhead_lng.present?
  end

  # e.g. "6,283 ft" — nil when elevation is unknown.
  def elevation_label
    return nil if trailhead_elevation_ft.blank?

    "#{ActiveSupport::NumberHelper.number_to_delimited(trailhead_elevation_ft)} ft"
  end

  private

  def enqueue_trailhead_enrichment
    EnrichTrailheadJob.perform_later(id) if name.present?
  end
end
