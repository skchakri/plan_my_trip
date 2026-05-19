class PlaceReview < ApplicationRecord
  include Discard::Model

  belongs_to :place
  belongs_to :author, class_name: "User"

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :body, length: { maximum: 4_000 }, allow_blank: true
  validates :author_id, uniqueness: { scope: :place_id, conditions: -> { kept } }

  scope :ordered, -> { order(created_at: :desc) }

  after_save     :refresh_place_aggregate
  after_discard  :refresh_place_aggregate
  after_undiscard :refresh_place_aggregate

  def edited?
    updated_at - created_at > 5
  end

  private

  def refresh_place_aggregate
    place.recompute_community_rating!
  end
end
