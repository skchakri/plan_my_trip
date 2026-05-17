class CreateBookingClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :booking_claims, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false # cars, stays, flights, activities
      t.text :note
      t.timestamps
    end
    add_index :booking_claims, [ :trip_id, :kind ], unique: true
  end
end
