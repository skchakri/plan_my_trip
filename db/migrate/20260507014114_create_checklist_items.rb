class CreateChecklistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_items, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.string :person
      t.string :category
      t.integer :position, null: false, default: 0
      t.boolean :packed, null: false, default: false

      t.timestamps
    end
    add_index :checklist_items, [ :trip_id, :position ]
    add_index :checklist_items, [ :trip_id, :category ]
  end
end
