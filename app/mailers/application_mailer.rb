class ApplicationMailer < ActionMailer::Base
  default from: -> { "#{Setting.store_name} <#{Rails.configuration.x.mailer.from}>" }
  layout "mailer"
  helper :mail

  private

  def operator_address = Setting.operator_email.presence || Rails.configuration.x.mailer.operator_email
  def subject_for(key, **args) = I18n.t("mailers.subjects.#{key}", store: Setting.store_name, **args)
end
