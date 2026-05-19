class AddHomeBaseToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string  :home_city
      t.decimal :home_lat, precision: 9, scale: 6
      t.decimal :home_lng, precision: 9, scale: 6
      t.integer :default_radius_km, default: 80, null: false
      t.jsonb   :default_interests, default: [], null: false
    end
  end
end
