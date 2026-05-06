class CreateTripMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_memberships, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false, default: "member"
      t.string :custom_title
      t.datetime :accepted_at

      t.timestamps
    end
    add_index :trip_memberships, [ :trip_id, :user_id ], unique: true
  end
end
