class CreateAppErrors < ActiveRecord::Migration[8.1]
  def change
    create_table :app_errors, id: :uuid do |t|
      t.string  :error_class,       null: false
      t.text    :message,           null: false
      t.text    :backtrace
      t.string  :fingerprint,       null: false
      t.integer :occurrences_count, null: false, default: 1
      t.datetime :first_occurred_at, null: false
      t.datetime :last_occurred_at,  null: false
      t.string  :severity,          null: false, default: "low"
      t.boolean :resolved,          null: false, default: false
      t.datetime :resolved_at
      t.jsonb   :context,           null: false, default: {}
      t.string  :source             # e.g. "job", "controller", "service"

      t.timestamps
    end

    add_index :app_errors, :fingerprint, unique: true
    add_index :app_errors, :resolved
    add_index :app_errors, :last_occurred_at
    add_index :app_errors, :severity
  end
end
