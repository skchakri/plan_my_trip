class AddFlightTrackingToReservations < ActiveRecord::Migration[8.1]
  def change
    # Parsed from the confirmation email (used to look the flight up).
    add_column :reservations, :flight_number, :string
    add_column :reservations, :carrier_code, :string

    # Live-status snapshot, refreshed by PollFlightStatusJob in the 24h before
    # departure. We diff against these to decide whether to alert.
    add_column :reservations, :flight_status, :string          # scheduled/delayed/cancelled/landed/…
    add_column :reservations, :gate, :string
    add_column :reservations, :terminal, :string
    add_column :reservations, :departure_delay_minutes, :integer
    add_column :reservations, :flight_checked_at, :datetime

    add_index :reservations, [ :kind, :start_at ]
  end
end
