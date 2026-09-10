module Notifications
  class OperatorMailer < ApplicationMailer
    before_action { @order = params[:order]; @review = params[:review]; @message = params[:message] }

    def order_created = mail(to: operator_address, subject: subject_for(:op_order_created, number: @order.number))
    def order_paid = mail(to: operator_address, subject: subject_for(:op_order_paid, number: @order.number))
    def order_cancelled = mail(to: operator_address, subject: subject_for(:op_order_cancelled, number: @order.number))
    def order_problem = mail(to: operator_address, subject: subject_for(:op_order_problem, number: @order.number))
    def review_submitted = mail(to: operator_address, subject: subject_for(:op_review_submitted, number: @review.order.number))
    def message_created = mail(to: operator_address, subject: subject_for(:op_message_created, name: @message.conversation.user.full_name))
  end
end
