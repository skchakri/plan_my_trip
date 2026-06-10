class AddNationalSymbols < ActiveRecord::Migration[8.1]
  def change
    # "National stuff" — feeds the Country Explorer fact-sheet and three quiz
    # decks (anthems, national birds, national sports).
    add_column :countries, :national_anthem, :string
    add_column :countries, :national_animal, :string
    add_column :countries, :national_bird,   :string
    add_column :countries, :national_flower, :string
    add_column :countries, :national_sport,  :string
    add_column :countries, :national_motto,  :string
    add_column :countries, :national_dish,   :string
  end
end
