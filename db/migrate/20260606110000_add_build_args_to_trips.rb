class AddBuildArgsToTrips < ActiveRecord::Migration[8.1]
  def change
    # Inputs the async build jobs need to (re)assemble a trip — selected highlight
    # slugs (multi-day) or selected idea slugs + q/depart/return (day trips). Kept
    # on the row so #rebuild can replay the exact build after a failure.
    add_column :trips, :build_args, :jsonb, null: false, default: {}
  end
end
