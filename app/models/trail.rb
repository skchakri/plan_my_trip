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

  def has_alltrails_link?
    alltrails_url.present?
  end
end
