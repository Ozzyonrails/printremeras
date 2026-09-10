# Business-tunable configuration. Every value has a sane default in DEFAULTS; admins
# override through /admin/settings. Values are cached; changes publish an audit log.
class Setting < ApplicationRecord
  DEFAULTS = {
    shipping_fee_cents:      { default: 350_000, type: :integer, group: :shipping },
    pickup_address:          { default: "Av. Corrientes 1234, CABA", type: :string, group: :shipping },
    pickup_hours:            { default: "Lun–Vie 10:00–18:00", type: :string, group: :shipping },
    courier_enabled:         { default: true, type: :boolean, group: :shipping },
    rush_enabled:            { default: false, type: :boolean, group: :production },
    rush_fee_cents:          { default: 500_000, type: :integer, group: :production },
    min_dpi:                 { default: 150, type: :integer, group: :editor },
    enforce_min_dpi:         { default: false, type: :boolean, group: :editor },
    enforce_min_upload_px:   { default: false, type: :boolean, group: :editor },
    image_enhancement_enabled: { default: true, type: :boolean, group: :editor },
    auto_request_enhancement: { default: false, type: :boolean, group: :editor },
    max_upload_bytes:        { default: 20 * 1024 * 1024, type: :integer, group: :editor },
    min_upload_px:           { default: 800, type: :integer, group: :editor },
    review_reward_percent:   { default: 25, type: :integer, group: :reviews },
    review_coupon_days:      { default: 90, type: :integer, group: :reviews },
    review_window_days:      { default: 60, type: :integer, group: :reviews },
    review_min_photos:       { default: 1, type: :integer, group: :reviews },
    review_max_photos:       { default: 5, type: :integer, group: :reviews },
    review_invitation_delay_days: { default: 3, type: :integer, group: :reviews },
    review_max_resubmissions: { default: 1, type: :integer, group: :reviews },
    guest_retention_days:    { default: 90, type: :integer, group: :identity },
    notification_channels:   { default: { "default" => [ "email" ] }, type: :json, group: :notifications },
    mercadopago_access_token: { default: nil, type: :secret, group: :payments },
    mercadopago_public_key:   { default: nil, type: :string, group: :payments },
    mercadopago_webhook_secret: { default: nil, type: :secret, group: :payments },
    store_name:              { default: "Printremeras", type: :string, group: :general },
    operator_email:          { default: nil, type: :string, group: :general }
  }.freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: DEFAULTS.keys.map(&:to_s) }

  after_commit { Setting.bust_cache }

  class << self
    def get(key)
      key = key.to_s
      spec = DEFAULTS.fetch(key.to_sym) { raise KeyError, "unknown setting #{key}" }
      cache_all.key?(key) ? cast(cache_all[key], spec[:type]) : spec[:default]
    end
    alias [] get

    def set(key, value)
      spec = DEFAULTS.fetch(key.to_sym) { raise KeyError, "unknown setting #{key}" }
      record = find_or_initialize_by(key: key.to_s)
      record.value = cast(value, spec[:type])
      record.save!
      record
    end

    def method_missing(name, *args, &block)
      DEFAULTS.key?(name) ? get(name) : super
    end

    def respond_to_missing?(name, include_private = false)
      DEFAULTS.key?(name) || super
    end

    def all_values
      DEFAULTS.keys.index_with { |k| get(k) }
    end

    def bust_cache
      Rails.cache.delete("settings/all")
    end

    private

    def cache_all
      Rails.cache.fetch("settings/all", expires_in: 5.minutes) { Setting.pluck(:key, :value).to_h }
    end

    def cast(value, type)
      return nil if value.nil? || (value.respond_to?(:empty?) && value.empty? && type != :json)
      case type
      when :integer then value.to_i
      when :boolean then ActiveModel::Type::Boolean.new.cast(value)
      when :json then value.is_a?(String) ? JSON.parse(value) : value
      else value.to_s
      end
    end
  end
end
