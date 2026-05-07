class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities, id: :uuid do |t|
      t.references :trip_day, null: false, foreign_key: true, type: :uuid
      t.string :time_label
      t.string :title, null: false
      t.string :location_name
      t.string :address
      t.string :photo_url
      t.text :notes
      t.string :group_label
      t.string :maps_url
      t.string :uber_url
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :activities, [ :trip_day_id, :position ]
  end
end
