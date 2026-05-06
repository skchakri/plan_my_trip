class CreateTripInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_invitations, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      t.references :inviter, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.string :email, null: false
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :declined_at
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :trip_invitations, :token, unique: true
    add_index :trip_invitations, :email
    add_index :trip_invitations, :discarded_at
  end
end
