class AddScopeToChecklistItems < ActiveRecord::Migration[8.1]
  def change
    add_column :checklist_items, :scope, :string, null: false, default: "before_trip"
    add_column :checklist_items, :day_label, :string
    add_column :checklist_items, :activity_label, :string
    add_index :checklist_items, [ :trip_id, :scope ]
  end
end
