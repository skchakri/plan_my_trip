class CreateSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :suggestions, id: :uuid do |t|
      t.references :trip_day, null: false, foreign_key: true, type: :uuid
      t.references :author,   null: false, type: :uuid
      t.string     :title,    null: false
      t.string     :url
      t.text       :notes
      t.datetime   :discarded_at
      t.timestamps
    end
    add_foreign_key :suggestions, :users, column: :author_id
    add_index :suggestions, [ :trip_day_id, :created_at ]
    add_index :suggestions, :discarded_at

    create_table :suggestion_votes, id: :uuid do |t|
      t.references :suggestion, null: false, foreign_key: true, type: :uuid
      t.references :user,       null: false, foreign_key: true, type: :uuid
      t.timestamps
    end
    add_index :suggestion_votes, [ :suggestion_id, :user_id ], unique: true
  end
end
