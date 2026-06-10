class AddLanguagesAndCallingCodes < ActiveRecord::Migration[8.1]
  def change
    # Two more facts on the existing Country row → two more quiz decks.
    add_column :countries, :primary_language, :string
    add_column :countries, :calling_code, :string
  end
end
