class CreateRoadTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :road_trips, id: :uuid do |t|
      t.string   :slug,             null: false
      t.string   :origin,           null: false
      t.string   :destination,      null: false
      t.string   :title,            null: false
      t.string   :tagline
      t.string   :hero_image_url
      t.string   :distance_label
      t.string   :drive_time_label
      t.integer  :suggested_days
      t.string   :best_season
      t.string   :transport_mode,   null: false, default: "own_car"
      t.decimal  :destination_lat,  precision: 9, scale: 6
      t.decimal  :destination_lng,  precision: 9, scale: 6
      t.text     :intro
      t.string   :seo_description
      t.string   :status,           null: false, default: "draft"
      t.integer  :position,         null: false, default: 0
      t.jsonb    :stops,            null: false, default: []
      t.jsonb    :itinerary,        null: false, default: []
      t.jsonb    :faqs,             null: false, default: []
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :road_trips, :slug, unique: true
    add_index :road_trips, :status
    add_index :road_trips, :discarded_at
    add_index :road_trips, :position
  end
end
