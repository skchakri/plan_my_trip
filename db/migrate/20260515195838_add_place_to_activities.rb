class AddPlaceToActivities < ActiveRecord::Migration[8.1]
  def change
    # Nullable: existing activities have no place yet, and admin-curated
    # rows may never link to a place. Backfill upgrades them in batch.
    add_reference :activities, :place, null: true, foreign_key: true, type: :uuid
  end
end
