class AllowGlobalRouteLandmarks < ActiveRecord::Migration[8.1]
  def up
    change_column_null :route_landmarks, :trip_id, true
    add_index :route_landmarks, :trip_id, where: "trip_id IS NULL", name: "index_route_landmarks_on_global", if_not_exists: true
  end

  def down
    remove_index :route_landmarks, name: "index_route_landmarks_on_global", if_exists: true
    # Don't flip the column back — there may be global rows that would violate it.
  end
end
