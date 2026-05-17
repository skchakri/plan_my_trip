class CreatePlaces < ActiveRecord::Migration[8.1]
  def change
    create_table :places, id: :uuid do |t|
      t.string  :name,             null: false
      t.string  :canonical_name
      t.decimal :latitude,         precision: 10, scale: 7
      t.decimal :longitude,        precision: 10, scale: 7
      t.text    :description
      t.text    :famous_for
      t.string  :image_url
      t.string  :image_source                # wikipedia | ai | user | google_places
      t.text    :image_attribution
      t.jsonb   :source_urls,      default: {}, null: false
      t.string  :kind                        # lodging | trail | restaurant | landmark | natural | etc
      t.integer :usage_count,      default: 0, null: false
      t.boolean :verified,         default: false, null: false
      t.references :contributed_by, type: :uuid, foreign_key: { to_table: :users }, null: true
      t.datetime :discarded_at
      t.timestamps
    end

    # Lookup by normalized name. Postgres functional index keeps the
    # case-insensitive find_or_seed fast even at 100k+ places.
    add_index :places, "lower(name)", name: "index_places_on_lower_name"

    # Bounded-box proximity dedupe: query "lat BETWEEN x AND y AND lng
    # BETWEEN p AND q" benefits from a compound index.
    add_index :places, [ :latitude, :longitude ], name: "index_places_on_lat_lng"

    add_index :places, :discarded_at
    add_index :places, :usage_count
  end
end
