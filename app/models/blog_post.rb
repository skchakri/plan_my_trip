# Admin-managed blog post. Replaces the old file-based BlogPost PORO
# (app/services/blog_post.rb) — posts are now DB rows editable at
# /admin/blog_posts. Body is Markdown, rendered by MarkdownHelper#render_markdown
# (Redcarpet) on the public /blog pages.
#
# Compatibility readers (cover / tag / author / published_on) preserve the old
# PORO's attribute names so the existing public blog views need no changes.
class BlogPost < ApplicationRecord
  include Discard::Model

  STATUSES = %w[draft published archived].freeze

  validates :title, :body, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase letters, numbers and hyphens" }
  validates :status, inclusion: { in: STATUSES }

  scope :published, -> { kept.where(status: "published").where("published_at IS NOT NULL AND published_at <= ?", Time.current) }
  scope :recent,    -> { order(Arel.sql("published_at DESC NULLS LAST"), created_at: :desc) }
  scope :tagged,    ->(tag) { where("? = ANY(tags)", tag) }

  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_validation :backfill_reading_minutes

  def to_param = slug

  def published?
    status == "published" && published_at.present? && published_at <= Time.current
  end

  # ── Back-compat readers so the public blog views (written against the old
  #    file-based PORO) keep working unchanged. ──────────────────────────
  def cover = cover_image_url
  def tag = tags.first
  def author = author_name
  def published_on = published_at&.to_date

  def reading_minutes
    self[:reading_minutes] || estimated_reading_minutes
  end

  private

  def estimated_reading_minutes
    [ (body.to_s.split.size / 200.0).ceil, 1 ].max
  end

  def generate_slug
    self.slug = title.parameterize
  end

  def backfill_reading_minutes
    self[:reading_minutes] = estimated_reading_minutes if self[:reading_minutes].blank? && body.present?
  end
end
