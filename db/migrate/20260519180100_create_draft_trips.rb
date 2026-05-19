class CreateDraftTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_trips, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.jsonb     :payload,     null: false, default: {}
      t.string    :step
      t.datetime  :last_step_at
      t.datetime  :expires_at,  null: false

      t.timestamps
    end

    add_index :draft_trips, :expires_at
  end
end
