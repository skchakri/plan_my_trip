class CreateTriviaQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :trivia_questions, id: :uuid do |t|
      t.string  :tag, null: false
      t.text    :question, null: false
      t.jsonb   :options, null: false, default: []
      t.integer :answer_index, null: false
      t.text    :fun_fact
      t.string  :difficulty
      t.string  :source, null: false, default: "seed"
      t.references :trip, type: :uuid, null: true, foreign_key: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :trivia_questions, :tag
    add_index :trivia_questions, :discarded_at
    add_index :trivia_questions, [ :tag, :trip_id ]
  end
end
