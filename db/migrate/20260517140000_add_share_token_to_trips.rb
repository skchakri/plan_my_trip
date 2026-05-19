class AddShareTokenToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :share_token,      :string
    add_column :trips, :share_revoked_at, :datetime
    # Partial unique index — the (likely many) NULL tokens don't need ordering.
    add_index  :trips, :share_token,
               unique: true,
               where: "share_token IS NOT NULL",
               name: "index_trips_on_share_token"
  end
end
