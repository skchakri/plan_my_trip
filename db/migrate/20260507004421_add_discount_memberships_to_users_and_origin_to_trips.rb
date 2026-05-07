class AddDiscountMembershipsToUsersAndOriginToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :discount_memberships, :jsonb, null: false, default: {}
    add_column :trips, :origin, :string
    add_column :trips, :traveler_count, :integer, null: false, default: 2
  end
end
