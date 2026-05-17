class AddChainToTriviaQuestions < ActiveRecord::Migration[8.1]
  def change
    add_reference :trivia_questions, :parent, type: :uuid, null: true,
                                              foreign_key: { to_table: :trivia_questions, on_delete: :cascade }
    add_column :trivia_questions, :chain_intro, :text
  end
end
