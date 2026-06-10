class Brand < ApplicationRecord
  CATEGORIES = %w[car airline].freeze

  validates :name, :category, :slug, presence: true
  validates :slug, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :for_category, ->(c) { where(category: c.to_s) }

  # Simple Icons CDN — free, no API key, returns the brand's colored mark as
  # an SVG keyed by slug. https://github.com/simple-icons/simple-icons
  def logo_url
    "https://cdn.simpleicons.org/#{slug}"
  end
end
