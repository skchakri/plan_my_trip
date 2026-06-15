class AddRemindersSentToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :reminders_sent, :jsonb, default: {}, null: false
  end
end
