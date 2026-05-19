class Suggestion < ApplicationRecord
  include Discard::Model

  belongs_to :trip_day
  belongs_to :author, class_name: "User"
  has_one :trip, through: :trip_day
  has_many :suggestion_votes, dependent: :destroy
  has_many :voters, through: :suggestion_votes, source: :user

  validates :title, presence: true, length: { maximum: 200 }
  validates :url, format: { with: %r{\Ahttps?://}, message: "must start with http(s)://" }, allow_blank: true

  scope :ranked, -> {
    kept
      .left_joins(:suggestion_votes)
      .group(:id)
      .select("suggestions.*, COUNT(suggestion_votes.id) AS vote_count")
      .order("vote_count DESC, suggestions.created_at ASC")
  }

  def vote_count
    self[:vote_count] || suggestion_votes.size
  end

  def voted_by?(user)
    return false unless user
    suggestion_votes.where(user_id: user.id).exists?
  end
end
