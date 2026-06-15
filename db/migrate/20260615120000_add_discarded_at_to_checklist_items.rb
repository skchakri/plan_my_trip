class AddDiscardedAtToChecklistItems < ActiveRecord::Migration[8.1]
  def change
    add_column :checklist_items, :discarded_at, :datetime
    add_index :checklist_items, :discarded_at
  end
end
