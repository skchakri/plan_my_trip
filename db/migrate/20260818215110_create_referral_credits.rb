class CreateReferralCredits < ActiveRecord::Migration[8.1]
  def change
    create_table :referral_credits, id: :uuid do |t|
      t.references :referrer, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :referee,  null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :trip,     null: true,  type: :uuid, foreign_key: true
      t.timestamps
    end
    # One credit per (sharer, saver) pair, however many trips get copied.
    add_index :referral_credits, %i[referrer_id referee_id], unique: true
  end
end
