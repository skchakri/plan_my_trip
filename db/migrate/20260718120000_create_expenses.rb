class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses, id: :uuid do |t|
      t.references :trip, null: false, foreign_key: true, type: :uuid
      # Who fronted the money. Nullifies (not cascades) if the traveler row is
      # removed, so the expense/history survives — it just shows "someone".
      t.references :paid_by, null: true, type: :uuid,
                   foreign_key: { to_table: :people, on_delete: :nullify }
      # Who logged it (for destroy authorization). Nullifies on user delete.
      t.references :created_by, null: true, type: :uuid,
                   foreign_key: { to_table: :users, on_delete: :nullify }

      t.string  :description, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string  :currency, null: false, default: "USD"
      t.string  :category
      # Person ids the cost is split across. Empty ⇒ split evenly among all
      # current travelers (resolved at read time, so adding a traveler later
      # doesn't retroactively change past splits unless left unset on purpose).
      t.jsonb   :split_between, null: false, default: []
      t.date    :incurred_on
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :expenses, :discarded_at
    add_index :expenses, [ :trip_id, :created_at ]
  end
end
