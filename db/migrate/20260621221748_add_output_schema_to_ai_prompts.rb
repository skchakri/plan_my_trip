class AddOutputSchemaToAiPrompts < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_prompts, :output_schema, :jsonb
  end
end
