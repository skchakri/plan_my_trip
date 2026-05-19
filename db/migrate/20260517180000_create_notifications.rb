class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :recipient, null: false, type: :uuid
      t.references :actor,     null: true,  type: :uuid
      t.references :subject,   polymorphic: true, type: :uuid, null: true
      t.string     :kind,      null: false
      t.string     :url
      t.string     :body
      t.datetime   :read_at
      t.timestamps
    end
    add_foreign_key :notifications, :users, column: :recipient_id
    add_foreign_key :notifications, :users, column: :actor_id

    add_index :notifications, [ :recipient_id, :read_at, :created_at ],
              name: "index_notifications_for_inbox"
  end
end
