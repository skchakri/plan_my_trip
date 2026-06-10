class AddCurrenciesAndLandmarks < ActiveRecord::Migration[8.1]
  def change
    # Powers the "World Currencies" deck — one more fact on the existing row.
    add_column :countries, :currency_name, :string

    # Powers the "Famous Landmarks" deck. `country` matches a Country#name;
    # `continent` is denormalized for distractor grouping.
    create_table :landmarks, id: :uuid do |t|
      t.string :name,      null: false
      t.string :country,   null: false
      t.string :continent
      t.timestamps
    end
    add_index :landmarks, :name, unique: true
    add_index :landmarks, :continent
  end
end
