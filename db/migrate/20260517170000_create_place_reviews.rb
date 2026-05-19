class CreatePlaceReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :place_reviews, id: :uuid do |t|
      t.references :place,  null: false, foreign_key: true, type: :uuid
      t.references :author, null: false, type: :uuid
      t.integer :rating, null: false
      t.text :body
      t.datetime :discarded_at
      t.timestamps
    end
    add_foreign_key :place_reviews, :users, column: :author_id
    add_index :place_reviews, [ :place_id, :created_at ]
    add_index :place_reviews, :discarded_at
    add_index :place_reviews, [ :place_id, :author_id ],
              unique: true,
              where: "discarded_at IS NULL",
              name: "index_place_reviews_one_per_user"

    change_table :places, bulk: true do |t|
      t.decimal :community_rating, precision: 3, scale: 2
      t.integer :community_rating_count, default: 0, null: false
    end
  end
end
