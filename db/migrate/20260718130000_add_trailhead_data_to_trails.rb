class AddTrailheadDataToTrails < ActiveRecord::Migration[8.1]
  def change
    add_column :trails, :trailhead_lat, :decimal, precision: 9, scale: 6
    add_column :trails, :trailhead_lng, :decimal, precision: 9, scale: 6
    add_column :trails, :trailhead_elevation_ft, :integer
    # When enrichment last ran (success or give-up), so we don't re-hit the free
    # geocode/elevation APIs on every save.
    add_column :trails, :enriched_at, :datetime
  end
end
