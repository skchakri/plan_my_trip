module Admin
  # Manage all external settings (API keys, affiliate IDs, paths) in one place,
  # backed by the AppSetting store. Secret values are write-only in the UI:
  # blank input leaves them unchanged; a "remove" checkbox clears an override.
  class AppSettingsController < BaseController
    def show
      @registry = AppSetting::REGISTRY
      @rows = AppSetting.where(key: AppSetting::KEYS).index_by(&:key)
    end

    def update
      changed = []
      AppSetting::REGISTRY.each do |d|
        if params.dig(:remove, d.key) == "1"
          rec = AppSetting.find_by(key: d.key)
          if rec
            rec.destroy
            changed << "#{d.label} cleared"
          end
          next
        end

        raw = params.dig(:app_settings, d.key).to_s
        next if raw.strip.empty? # blank = leave unchanged (don't wipe secrets)

        existing = AppSetting.find_by(key: d.key)&.value
        next if existing == raw.strip # no-op

        AppSetting.set(d.key, raw)
        changed << "#{d.label} saved"
      end

      notice = changed.any? ? changed.to_sentence : "No changes."
      redirect_to admin_app_settings_path, notice: notice
    end
  end
end
