class AddLatLngToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :latitude,  :decimal, precision: 10, scale: 7
    add_column :activities, :longitude, :decimal, precision: 10, scale: 7
  end
end
