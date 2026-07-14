class AddMustIncludesToTrips < ActiveRecord::Migration[8.1]
  def change
    # Traveler-mandated anchors from the wizard ("Disneyland — 2 days",
    # "a beach day"). Array of short strings; hard constraints for the
    # itinerary builder.
    add_column :trips, :must_includes, :jsonb, null: false, default: []
  end
end
