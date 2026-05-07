class AddPwaUrlsToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :pwa_plan_url, :string
    add_column :trips, :pwa_packing_url, :string
  end
end
