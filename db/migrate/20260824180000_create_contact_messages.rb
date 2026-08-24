class CreateContactMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_messages, id: :uuid do |t|
      t.string  :name, limit: 120
      t.string  :email, null: false
      t.text    :body, null: false
      t.references :user, type: :uuid, null: true, foreign_key: true
      t.string  :ip
      t.string  :user_agent
      t.boolean :spam, null: false, default: false
      t.string  :spam_reason
      t.datetime :read_at
      t.datetime :replied_at
      t.text :reply_body
      t.timestamps
    end
    add_index :contact_messages, :created_at
    add_index :contact_messages, %i[spam read_at]
  end
end
