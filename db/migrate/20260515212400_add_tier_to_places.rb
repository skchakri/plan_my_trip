class AddTierToPlaces < ActiveRecord::Migration[8.1]
  def change
    add_column :places, :tier, :string
    add_column :places, :region, :string
    add_index  :places, :tier
    add_index  :places, :region
  end
end
