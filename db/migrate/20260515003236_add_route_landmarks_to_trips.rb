class AddRouteLandmarksToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :route_landmarks, :jsonb, default: [], null: false
  end
end
