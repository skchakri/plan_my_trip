class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      # Optional day slotting — set when start_at lands on a TripDay.date.
      t.references :trip_day, null: true, foreign_key: true, type: :uuid

      t.string   :kind, null: false, default: "other"   # stay/flight/car/activity/rail/other
      t.string   :status, null: false, default: "parsing" # parsing/parsed/failed
      t.string   :vendor
      t.string   :confirmation_number
      t.string   :title
      t.string   :location
      t.string   :address
      t.datetime :start_at
      t.datetime :end_at
      t.text     :notes
      t.text     :raw_email           # the forwarded body (capped on write)
      t.string   :source_from         # the address the forward came from
      t.jsonb    :parsed, default: {}, null: false # full extractor payload
      t.datetime :discarded_at        # soft delete (Discard)

      t.timestamps
    end

    add_index :reservations, :discarded_at
    add_index :reservations, [ :trip_id, :kind ]
    # De-dupe guard for repeated forwards of the same confirmation onto a trip.
    add_index :reservations, [ :trip_id, :confirmation_number ],
              unique: true,
              where: "confirmation_number IS NOT NULL AND discarded_at IS NULL",
              name: "index_reservations_on_trip_and_confirmation"
  end
end
