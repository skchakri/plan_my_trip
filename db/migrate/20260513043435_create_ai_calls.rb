class CreateAiCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_calls, id: :uuid do |t|
      t.timestamps
    end
  end
end
