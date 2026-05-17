class FixAiPromptsAndCalls < ActiveRecord::Migration[8.1]
  def change
    # ai_prompts — fill in the columns the original migration was generated
    # with but never had written (Write error during initial build).
    change_table :ai_prompts do |t|
      t.string  :slug, null: false
      t.string  :name, null: false
      t.text    :description
      t.text    :system_template
      t.text    :user_template, null: false
      t.string  :provider, null: false, default: "anthropic"
      t.string  :model,    null: false
      t.string  :kind,     null: false, default: "text"
      t.integer :max_tokens
      t.decimal :temperature, precision: 4, scale: 2
      t.boolean :active, null: false, default: true
      t.text    :notes
    end
    add_index :ai_prompts, :slug, unique: true
    add_index :ai_prompts, :provider
    add_index :ai_prompts, :active

    # ai_calls — same situation.
    change_table :ai_calls do |t|
      t.references :ai_prompt, type: :uuid, foreign_key: true
      t.references :user,      type: :uuid, foreign_key: { to_table: :users }
      t.references :trip,      type: :uuid, foreign_key: true
      t.string  :prompt_slug, null: false
      t.string  :provider,    null: false
      t.string  :model,       null: false
      t.string  :status,      null: false, default: "pending"
      t.jsonb   :input_variables, null: false, default: {}
      t.text    :rendered_system
      t.text    :rendered_user
      t.text    :response_text
      t.string  :image_url
      t.text    :error
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :latency_ms
      t.jsonb   :meta, null: false, default: {}
    end
    add_index :ai_calls, :prompt_slug
    add_index :ai_calls, :status
    add_index :ai_calls, :created_at
  end
end
