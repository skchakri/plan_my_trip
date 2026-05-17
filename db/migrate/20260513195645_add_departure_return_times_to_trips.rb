class AddDepartureReturnTimesToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :departure_time, :time
    add_column :trips, :return_time, :time
  end
end
