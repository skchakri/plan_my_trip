class AddBuildStatusToTrips < ActiveRecord::Migration[8.1]
  def change
    # "ready" by default so every existing trip (already fully built) is shown
    # normally; only new wizard trips start as "building" while BuildTripJob runs.
    add_column :trips, :build_status, :string, null: false, default: "ready"
    add_column :trips, :build_error, :text
    add_index :trips, :build_status
  end
end
