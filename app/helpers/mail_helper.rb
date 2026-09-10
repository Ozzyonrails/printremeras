module MailHelper
  def money(cents, currency = "ARS") = Money.format(cents, currency: currency)
  def order_url_for(order) = "#{Rails.configuration.x.app.public_url}/orders/#{order.number}"
  def admin_order_url_for(order) = "#{Rails.configuration.x.app.public_url}/admin/orders/#{order.number}"
end
