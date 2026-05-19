class AddDayTripToTrips < ActiveRecord::Migration[8.1]
  def change
    change_table :trips, bulk: true do |t|
      t.boolean :day_trip, default: false, null: false
      t.decimal :anchor_lat, precision: 9, scale: 6
      t.decimal :anchor_lng, precision: 9, scale: 6
      t.string  :anchor_label
      t.integer :max_radius_km
      t.jsonb   :interests, default: [], null: false
    end

    add_index :trips, :day_trip
  end
end
