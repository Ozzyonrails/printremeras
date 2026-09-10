module Identity
  class AccountMailer < ApplicationMailer
    before_action { @user = params[:user]; @token = params[:token] }

    def confirmation
      @url = "#{Rails.configuration.x.app.public_url}/confirm/#{@token}"
      I18n.with_locale(@user.locale) { mail(to: @user.email, subject: subject_for(:confirmation)) }
    end

    def password_reset
      @url = "#{Rails.configuration.x.app.public_url}/reset-password/#{@token}"
      I18n.with_locale(@user.locale) { mail(to: @user.email, subject: subject_for(:password_reset)) }
    end
  end
end
