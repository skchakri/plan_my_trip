class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :activity, null: false, foreign_key: true, type: :uuid
      t.references :author,   null: false, type: :uuid
      t.text :body, null: false
      t.datetime :discarded_at
      t.timestamps
    end
    add_foreign_key :comments, :users, column: :author_id
    add_index :comments, [ :activity_id, :created_at ]
    add_index :comments, :discarded_at
  end
end
