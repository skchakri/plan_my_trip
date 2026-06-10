class CreateBrands < ActiveRecord::Migration[8.1]
  def change
    # Logos for the "guess the brand" decks (cars, airlines). The image itself
    # is served at runtime by Simple Icons (cdn.simpleicons.org/<slug>) — only
    # the slug is stored, no binaries.
    create_table :brands, id: :uuid do |t|
      t.string :name,     null: false
      t.string :category, null: false  # "car" | "airline"
      t.string :slug,     null: false  # Simple Icons slug
      t.timestamps
    end
    add_index :brands, :slug, unique: true
    add_index :brands, :category
  end
end
