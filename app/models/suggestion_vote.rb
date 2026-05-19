class SuggestionVote < ApplicationRecord
  belongs_to :suggestion
  belongs_to :user

  validates :user_id, uniqueness: { scope: :suggestion_id }
end
