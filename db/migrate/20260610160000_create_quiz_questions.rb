class CreateQuizQuestions < ActiveRecord::Migration[8.1]
  def change
    # Pre-generated question bank. `payload` is the full question hash
    # (prompt, options/option_images/option_labels, answer_index, image_url,
    # flag_thumb, logo) — format-agnostic so text, single-image, and
    # four-image decks all store the same way. Regenerate via `rake quiz:rebuild`.
    create_table :quiz_questions, id: :uuid do |t|
      t.string :category, null: false
      t.jsonb  :payload,  null: false, default: {}
      t.timestamps
    end
    add_index :quiz_questions, :category
  end
end
