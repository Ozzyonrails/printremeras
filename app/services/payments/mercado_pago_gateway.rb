require "net/http"
require "openssl"

module Payments
  # MercadoPago adapter (Checkout Pro). The only file allowed to know about MercadoPago.
  # Credentials: Setting.mercadopago_access_token (admin UI) or MERCADOPAGO_ACCESS_TOKEN.
  class MercadoPagoGateway < Gateway
    API = "https://api.mercadopago.com".freeze
    STATUS_MAP = { "approved" => "approved", "authorized" => "pending", "in_process" => "pending", "pending" => "pending",
                   "in_mediation" => "pending", "rejected" => "rejected", "cancelled" => "cancelled", "refunded" => "refunded", "charged_back" => "refunded" }.freeze

    def provider = "mercadopago"
    def configured? = access_token.present?

    def create_checkout(order:, payment:, flow:, return_urls:)
      body = {
        items: order.items.map { |i| { id: i.id.to_s, title: "#{i.title} (#{i.size_label})", quantity: i.quantity, unit_price: cents_to_amount(i.unit_price_cents), currency_id: order.currency } },
        payer: { email: order.user.email, name: order.user.first_name, surname: order.user.last_name },
        external_reference: payment.external_reference,
        back_urls: { success: return_urls[:success], failure: return_urls[:failure], pending: return_urls[:pending] },
        auto_return: "approved",
        notification_url: return_urls[:webhook],
        statement_descriptor: Setting.store_name.to_s.first(22),
        metadata: { order_number: order.number, payment_id: payment.id },
        expires: true,
        expiration_date_from: Time.current.iso8601,
        expiration_date_to: 24.hours.from_now.iso8601
      }
      extras = order.total_cents - order.items.sum(&:line_total_cents)
      body[:items] << { id: "adjustments", title: I18n.t("payments.adjustments"), quantity: 1, unit_price: cents_to_amount(extras), currency_id: order.currency } if extras.positive?
      body[:items] << { id: "discount", title: I18n.t("payments.discount"), quantity: 1, unit_price: cents_to_amount(extras), currency_id: order.currency } if extras.negative?

      resp = request(:post, "/checkout/preferences", body, idempotency_key: "pref-#{payment.id}")
      url = resp["init_point"]
      Checkout.new(preference_id: resp["id"], checkout_url: url, qr_data: url, raw: resp)
    end

    def fetch_payment(provider_payment_id)
      resp = request(:get, "/v1/payments/#{provider_payment_id}")
      PaymentInfo.new(provider_payment_id: resp["id"].to_s, status: STATUS_MAP.fetch(resp["status"], "pending"),
                      amount_cents: amount_to_cents(resp["transaction_amount"]), currency: resp["currency_id"],
                      external_reference: resp["external_reference"], raw: resp)
    end

    # MercadoPago sends either query params (?topic=payment&id=123) or a JSON body
    # ({"type":"payment","data":{"id":"123"}}). Signature is verified when a secret is set.
    def parse_notification(params:, headers:, raw_body:)
      type = params["type"].presence || params["topic"].presence
      return nil unless type.to_s == "payment"
      payment_id = params.dig("data", "id").presence || params["data.id"].presence || params["id"]
      return nil if payment_id.blank?
      verify_signature!(payment_id: payment_id, headers: headers) if webhook_secret.present?
      Notification.new(event_id: "#{payment_id}-#{params['action'] || params['id'] || 'notice'}-#{headers['x-request-id'].presence || Digest::SHA1.hexdigest(raw_body.to_s)[0, 8]}",
                       event_type: type, payment_id: payment_id.to_s, raw: params.to_h)
    end

    def refund(payment)
      resp = request(:post, "/v1/payments/#{payment.provider_payment_id}/refunds", {}, idempotency_key: "refund-#{payment.id}")
      PaymentInfo.new(provider_payment_id: payment.provider_payment_id, status: "refunded", amount_cents: amount_to_cents(resp["amount"]), currency: payment.currency, external_reference: payment.external_reference, raw: resp)
    end

    private

    def access_token = Setting.mercadopago_access_token.presence || ENV["MERCADOPAGO_ACCESS_TOKEN"]
    def webhook_secret = Setting.mercadopago_webhook_secret.presence || ENV["MERCADOPAGO_WEBHOOK_SECRET"]
    def cents_to_amount(cents) = (cents.to_i / 100.0).round(2)
    def amount_to_cents(amount) = (amount.to_f * 100).round

    def verify_signature!(payment_id:, headers:)
      sig = headers["x-signature"].to_s
      parts = sig.split(",").to_h { |kv| kv.strip.split("=", 2) }
      ts, v1 = parts["ts"], parts["v1"]
      raise Error, "missing signature" if ts.blank? || v1.blank?
      manifest = "id:#{payment_id.to_s.downcase};request-id:#{headers['x-request-id']};ts:#{ts};"
      expected = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, manifest)
      raise Error, "invalid webhook signature" unless ActiveSupport::SecurityUtils.secure_compare(expected, v1)
    end

    def request(method, path, body = nil, idempotency_key: nil)
      raise Error, "MercadoPago access token not configured" if access_token.blank?
      uri = URI("#{API}#{path}")
      req = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["Content-Type"] = "application/json"
      req["X-Idempotency-Key"] = idempotency_key if idempotency_key
      req.body = body.to_json if body
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) { |http| http.request(req) }
      json = JSON.parse(res.body.presence || "{}")
      raise Error, "MercadoPago #{res.code}: #{json['message'] || json['error'] || res.body.to_s.first(200)}" unless res.is_a?(Net::HTTPSuccess)
      json
    end
  end
end
