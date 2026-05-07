class CreateTripDays < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_days, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      t.date :date
      t.string :title, null: false
      t.string :theme
      t.string :accent, null: false, default: "gold"
      t.string :label, null: false
      t.text :summary
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :trip_days, [ :trip_id, :position ]
    add_index :trip_days, [ :trip_id, :label ]
  end
end
