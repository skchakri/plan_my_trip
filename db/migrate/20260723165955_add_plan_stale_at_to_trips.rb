class AddPlanStaleAtToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :plan_stale_at, :datetime
  end
end
