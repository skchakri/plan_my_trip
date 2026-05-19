class AddCacheSettingsToAiPrompts < ActiveRecord::Migration[8.1]
  def change
    change_table :ai_prompts, bulk: true do |t|
      t.boolean :cacheable, null: false, default: true
      t.integer :cache_ttl_seconds # nil → use Ai::Caller::CACHE_TTL default
    end
  end
end
