module Admin
  # Language switcher in the admin top bar. The choice is stored on the admin user, so it
  # survives sessions and is also the language their notification emails use.
  class LocalesController < BaseController
    def update
      locale = params[:locale].to_s
      return redirect_back(fallback_location: admin_root_path, alert: t("admin.locales.unknown")) unless I18n.available_locales.map(&:to_s).include?(locale)

      current_admin.update!(locale: locale)
      redirect_back fallback_location: admin_root_path
    end
  end
end
