class CreateSupportTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :support_tickets, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string   :subject,           null: false
      t.string   :status,            null: false, default: "open"
      t.string   :category
      t.text     :admin_draft
      t.string   :escalation_reason
      t.integer  :ai_attempts,       null: false, default: 0
      t.datetime :last_activity_at
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :support_tickets, :status
    add_index :support_tickets, :discarded_at
    add_index :support_tickets, [ :status, :last_activity_at ]
  end
end
