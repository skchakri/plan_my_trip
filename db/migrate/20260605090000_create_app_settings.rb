class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings, id: :uuid do |t|
      t.string :key, null: false
      # API keys / IDs, encrypted at rest via ActiveSupport::MessageEncryptor
      # (key derived from secret_key_base). Human-facing metadata
      # (label/category/description/default) lives in AppSetting::REGISTRY.
      t.text :encrypted_value
      t.timestamps
    end
    add_index :app_settings, :key, unique: true
  end
end
