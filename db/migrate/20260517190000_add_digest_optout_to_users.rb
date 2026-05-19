class AddDigestOptoutToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :digest_optout_at,        :datetime
    add_column :users, :digest_last_sent_at,     :datetime
  end
end
