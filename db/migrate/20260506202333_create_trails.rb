class CreateTrails < ActiveRecord::Migration[8.1]
  def change
    create_table :trails, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :alltrails_url
      t.text :notes
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :trails, [ :trip_id, :position ]
  end
end
