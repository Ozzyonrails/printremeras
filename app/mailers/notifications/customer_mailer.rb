module Notifications
  class CustomerMailer < ApplicationMailer
    before_action { @user = params[:user]; @order = params[:order]; @review = params[:review]; @message = params[:message] }

    def order_approved = mail_to_user(subject_for(:order_approved, number: @order.number))
    def order_rejected = mail_to_user(subject_for(:order_rejected, number: @order.number))
    def order_paid = mail_to_user(subject_for(:order_paid, number: @order.number))
    def order_cancelled = mail_to_user(subject_for(:order_cancelled, number: @order.number))
    def order_problem = mail_to_user(subject_for(:order_problem, number: @order.number))
    def order_refunded = mail_to_user(subject_for(:order_refunded, number: @order.number))
    def payment_failed = mail_to_user(subject_for(:payment_failed, number: @order.number))
    def review_approved = mail_to_user(subject_for(:review_approved))
    def review_rejected = mail_to_user(subject_for(:review_rejected))
    def review_invitation = mail_to_user(subject_for(:review_invitation, number: @order.number))
    def message_created = mail_to_user(subject_for(:message_created))

    def order_status_changed
      @to = params[:to]
      mail_to_user(subject_for(:order_status_changed, number: @order.number, status: I18n.t("orders.statuses.#{@to}")))
    end

    private

    def mail_to_user(subject)
      mail(to: @user.email, subject: subject)
    end
  end
end
