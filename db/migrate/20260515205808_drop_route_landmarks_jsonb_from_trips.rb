class DropRouteLandmarksJsonbFromTrips < ActiveRecord::Migration[8.1]
  def up
    remove_column :trips, :route_landmarks
  end

  def down
    add_column :trips, :route_landmarks, :jsonb, default: [], null: false
  end
end
