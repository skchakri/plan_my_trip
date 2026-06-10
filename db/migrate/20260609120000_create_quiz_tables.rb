class CreateQuizTables < ActiveRecord::Migration[8.1]
  def change
    # Reference data for the standalone Travel Trivia quizzes. One Country row
    # powers three categories: capitals, flags, and world leaders.
    create_table :countries, id: :uuid do |t|
      t.string :name,         null: false
      t.string :capital,      null: false
      t.string :iso2,         null: false   # lowercase ISO-3166 alpha-2 (flagcdn key)
      t.string :continent
      t.string :leader_title
      t.string :leader_name
      t.timestamps
    end
    add_index :countries, :name, unique: true
    add_index :countries, :iso2, unique: true
    add_index :countries, :continent

    create_table :us_states, id: :uuid do |t|
      t.string :name,         null: false
      t.string :capital,      null: false
      t.string :abbreviation, null: false
      t.timestamps
    end
    add_index :us_states, :name, unique: true
    add_index :us_states, :abbreviation, unique: true

    # One row per completed quiz, used for per-category personal bests + history.
    create_table :quiz_attempts, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string  :category, null: false
      t.integer :score,    null: false, default: 0
      t.integer :total,    null: false, default: 0
      t.timestamps
    end
    add_index :quiz_attempts, [ :user_id, :category ]
  end
end
