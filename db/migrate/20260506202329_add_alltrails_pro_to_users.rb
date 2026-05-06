class AddAlltrailsProToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :alltrails_pro, :boolean, null: false, default: false
  end
end
