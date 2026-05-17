class AddTransportModeToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :transport_mode, :string
  end
end
