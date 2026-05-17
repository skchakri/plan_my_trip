class CreateTriviaResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :trivia_responses, id: :uuid do |t|
      t.references :person, type: :uuid, null: false, foreign_key: true
      t.references :trivia_question, type: :uuid, null: false, foreign_key: true
      t.boolean  :correct, null: false, default: false
      t.datetime :answered_at, null: false

      t.timestamps
    end

    # One response per (person, question) — re-answering updates the same row.
    add_index :trivia_responses, [ :person_id, :trivia_question_id ], unique: true, name: "idx_trivia_responses_person_question"
  end
end
