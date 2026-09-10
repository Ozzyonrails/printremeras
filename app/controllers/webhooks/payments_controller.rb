module Webhooks
  # Accept, persist, respond 200 — processing happens in a job (§14).
  class PaymentsController < ActionController::API
    def create
      result = Payments::HandleWebhook.call(provider: params[:provider], params: request.request_parameters.merge(request.query_parameters).to_h,
                                            headers: request.headers.to_h.select { |k, _| k.start_with?("HTTP_") }.transform_keys { |k| k.sub("HTTP_", "").downcase.tr("_", "-") },
                                            raw_body: request.raw_post)
      if result.success?
        head :ok
      else
        head(result.code == :not_found ? :not_found : :unauthorized)
      end
    end
  end
end
