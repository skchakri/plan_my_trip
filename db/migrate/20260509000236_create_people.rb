class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :age
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :people, [ :trip_id, :position ]
  end
end
