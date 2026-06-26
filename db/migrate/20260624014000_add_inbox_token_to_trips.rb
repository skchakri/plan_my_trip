class AddInboxTokenToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :inbox_token, :string
    # Unique only among trips that have minted a token (lazy minting leaves the
    # rest NULL). Kept separate from share_token so revoking the public link
    # never disables email import.
    add_index :trips, :inbox_token, unique: true, where: "inbox_token IS NOT NULL"
  end
end
