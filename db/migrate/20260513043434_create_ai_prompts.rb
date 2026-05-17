class CreateAiPrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_prompts, id: :uuid do |t|
      t.timestamps
    end
  end
end
