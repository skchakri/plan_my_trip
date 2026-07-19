class CreateSupportMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :support_messages, id: :uuid do |t|
      t.references :support_ticket, null: false, type: :uuid, foreign_key: true
      t.string   :role, null: false # user / assistant / admin
      t.text     :body, null: false
      t.references :author, type: :uuid, foreign_key: { to_table: :users } # null for AI (assistant)
      t.timestamps
    end

    add_index :support_messages, [ :support_ticket_id, :created_at ]
  end
end
