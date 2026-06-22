class AddBuildStepToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :build_step, :integer, default: 0, null: false
  end
end
