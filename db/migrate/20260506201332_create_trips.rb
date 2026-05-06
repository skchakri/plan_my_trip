class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips, id: :uuid do |t|
      t.references :owner, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :destination
      t.date :start_date
      t.date :end_date
      t.text :body
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :trips, :discarded_at
  end
end
