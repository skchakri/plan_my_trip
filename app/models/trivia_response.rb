class TriviaResponse < ApplicationRecord
  belongs_to :person
  belongs_to :trivia_question

  validates :answered_at, presence: true
  validates :person_id, uniqueness: { scope: :trivia_question_id }
end
