# Resolution order (§19): URL parameter → user preference → Accept-Language → default.
module LocaleResolution
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private

  def switch_locale(&action)
    I18n.with_locale(resolve_locale, &action)
  end

  def resolve_locale
    available = I18n.available_locales.map(&:to_s)
    candidates = [ params[:locale], locale_preference, http_accept_locale ]
    (candidates.compact.map(&:to_s).find { |l| available.include?(l) } || I18n.default_locale).to_sym
  end

  def locale_preference
    respond_to?(:current_user, true) && current_user&.locale
  end

  def http_accept_locale
    header = request.env["HTTP_ACCEPT_LANGUAGE"].to_s
    header.split(",").map { |part| part.split(";").first.to_s.strip[0, 2].downcase }.find { |l| I18n.available_locales.map(&:to_s).include?(l) }
  end
end
