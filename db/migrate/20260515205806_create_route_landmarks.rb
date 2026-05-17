class CreateRouteLandmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :route_landmarks, id: :uuid do |t|
      t.references :trip, type: :uuid, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :kind, null: false, default: "scenic"
      t.decimal :latitude,  precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.text    :narration, null: false
      t.string  :image_url
      t.string  :wikipedia_url
      t.integer :position, null: false, default: 0
      t.string  :source, null: false, default: "ai"
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :route_landmarks, [ :trip_id, :position ]
    add_index :route_landmarks, :discarded_at
  end
end
