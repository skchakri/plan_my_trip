class AddSlugToPlaces < ActiveRecord::Migration[8.1]
  def change
    add_column :places, :slug, :string
    add_index  :places, :slug, unique: true, where: "slug IS NOT NULL", name: "index_places_on_slug"
  end
end
