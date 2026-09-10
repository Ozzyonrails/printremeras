module Admin
  class SettingsController < BaseController
    before_action :require_admin_role!

    def show
      @groups = Setting::DEFAULTS.group_by { |_, spec| spec[:group] }
      @values = Setting.all_values
    end

    def update
      changes = {}
      params.fetch(:settings, {}).each do |key, value|
        next unless Setting::DEFAULTS.key?(key.to_sym)
        spec = Setting::DEFAULTS[key.to_sym]
        next if spec[:type] == :secret && value.blank? # keep existing secret when field left empty
        before = Setting.get(key)
        Setting.set(key, value)
        after = Setting.get(key)
        changes[key] = { "from" => spec[:type] == :secret ? "[hidden]" : before, "to" => spec[:type] == :secret ? "[hidden]" : after } if before != after
      end
      audit!("settings.changed", nil, changes) if changes.any?
      redirect_to admin_settings_path, notice: t("admin.saved")
    rescue JSON::ParserError => e
      redirect_to admin_settings_path, alert: "JSON: #{e.message}"
    end
  end
end
