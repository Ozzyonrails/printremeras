# Plain-hash serializers for the JSON API. Kept together so API shapes are easy to audit.
module Serializers
  module_function

  def user(user)
    return nil unless user
    { id: user.id, email: user.email, first_name: user.first_name, last_name: user.last_name, phone: user.phone,
      locale: user.locale, confirmed: user.confirmed?, has_password: user.password_digest.present?, google: user.google_uid.present? }
  end

  def print_area(area)
    { id: area.id, side: area.side, x: area.x.to_f, y: area.y.to_f, w: area.w.to_f, h: area.h.to_f,
      width_mm: area.width_mm.to_f, height_mm: area.height_mm.to_f, min_dpi: area.effective_min_dpi,
      mockup_url: Rendering::Urls.variant_path(area.mockup, :editor), mockup_card_url: Rendering::Urls.variant_path(area.mockup, :card),
      mockup_thumb_url: Rendering::Urls.variant_path(area.mockup, :thumb),
      mockup_width_px: area.mockup_width_px, mockup_height_px: area.mockup_height_px }
  end

  def template_size(size)
    { id: size.id, label: size.label, stock: size.stock, available: size.available?, restock_at: size.restock_at&.iso8601 }
  end

  def template(t, full: false)
    base = { id: t.id, slug: t.slug, kind: t.kind, name: t.name, description: t.description, color_name: t.color_name, color_label: t.color_label, color_hex: t.color_hex,
             base_price_cents: t.base_price_cents, print_price_one_side_cents: t.print_price_one_side_cents,
             print_price_two_sides_cents: t.print_price_two_sides_cents, image_url: Rendering::Urls.variant_path((t.front_area || t.print_areas.first)&.mockup, :card),
             sizes: t.template_sizes.map { |s| template_size(s) } }
    full ? base.merge(print_areas: t.print_areas.ordered.map { |a| print_area(a) }) : base
  end

  def design(d)
    { id: d.id, width_px: d.effective_width_px, height_px: d.effective_height_px,
      uploaded_width_px: d.width_px, uploaded_height_px: d.height_px,
      content_type: d.content_type, source: d.source,
      url: Rendering::Urls.blob_path(d.print_ready_file), thumb_url: Rendering::Urls.variant_path(d.file, :thumb),
      license_note: d.license_note, enhancement_status: d.enhancement_status, enhanced: d.enhanced?,
      needs_enhancement: d.needs_enhancement?, enhancement_note: d.enhancement_note }
  end

  def placement(p)
    { id: p.id, design_id: p.design_id, print_area_id: p.print_area_id, side: p.print_area.side, x: p.x.to_f, y: p.y.to_f,
      scale: p.scale.to_f, rotation: p.rotation.to_f, effective_dpi: p.effective_dpi.round, low_quality: p.low_quality?,
      min_dpi: p.print_area.effective_min_dpi, design: design(p.design) }
  end

  def catalog_item(c, full: false)
    base = { id: c.id, slug: c.slug, title: c.title, description: c.description, price_cents: c.price_cents, tags: c.tags,
             image_url: Rendering::Urls.variant_path(c.preview, :card), large_image_url: Rendering::Urls.variant_path(c.preview, :large),
             template: template(c.template), sides_count: c.sides_count }
    full ? base.merge(template: template(c.template, full: true), placements: c.placements.includes(:design, :print_area).map { |p| placement(p) }) : base
  end

  def cart_item(item)
    line = Orders::Pricing.line_for(item)
    { id: item.id, quantity: item.quantity, template: template(item.template, full: true), size: template_size(item.template_size),
      catalog_item: item.catalog_item && catalog_item(item.catalog_item), custom: item.custom?,
      placements: item.placements.includes(:design, :print_area).map { |p| placement(p) },
      sides_count: line[:sides_count], unit_price_cents: line[:unit_price_cents], line_total_cents: line[:line_total_cents] }
  end

  def cart(cart)
    items = cart.items.includes(:template, :template_size, :catalog_item, placements: [ :design, :print_area ]).order(:id)
    { id: cart.id, items: items.map { |i| cart_item(i) }, subtotal_cents: Orders::Pricing.subtotal_cents(items), total_quantity: items.sum(&:quantity) }
  end

  def quote(q)
    { valid: q.valid, errors: q.errors, subtotal_cents: q.subtotal_cents, discount_cents: q.discount_cents, coupon_code: q.coupon&.code,
      coupon_error: q.coupon_error, rush: q.rush, rush_fee_cents: q.rush_fee_cents, shipping_fee_cents: q.shipping_fee_cents,
      shipping_method: q.shipping_method, total_cents: q.total_cents, requires_moderation: q.requires_moderation }
  end

  def address(a)
    a.slice(:id, :recipient_name, :phone, :street, :number, :apartment, :floor, :neighborhood, :postal_code, :city, :notes, :is_default).merge(one_line: a.one_line)
  end

  def order_item(i)
    { id: i.id, quantity: i.quantity, unit_price_cents: i.unit_price_cents, line_total_cents: i.line_total_cents, sides_count: i.sides_count,
      custom: i.custom?, snapshot: i.snapshot, title: i.title, size_label: i.size_label,
      preview_url: Rendering::Urls.variant_path(i.preview, :thumb) || (i.catalog_item && Rendering::Urls.variant_path(i.catalog_item.preview, :card)) || Rendering::Urls.template_thumb(i.template),
      placements: i.placements.includes(:design, :print_area).map { |p| placement(p) } }
  end

  def order(o, full: false)
    base = { id: o.id, number: o.number, status: o.status, status_label: I18n.t("orders.statuses.#{o.status}"), total_cents: o.total_cents,
             subtotal_cents: o.subtotal_cents, discount_cents: o.discount_cents, rush_fee_cents: o.rush_fee_cents, shipping_fee_cents: o.shipping_fee_cents,
             shipping_method: o.shipping_method, placed_at: o.placed_at&.iso8601, paid_at: o.paid_at&.iso8601, delivered_at: o.delivered_at&.iso8601,
             item_count: o.items.sum(:quantity), preview_url: Rendering::Urls.order_preview_url(o), can_cancel: o.customer_can_cancel?,
             can_pay: o.awaiting_payment?, can_review: o.can_be_reviewed?, review_status: o.review&.status, rejection_reason: o.rejection_reason,
             low_quality_artwork: o.low_quality_artwork }
    return base unless full
    base.merge(items: o.items.includes(:template, :catalog_item).map { |i| order_item(i) }, shipping_address: o.shipping_address, coupon_code: o.coupon_code,
               customer_notes: o.customer_notes, problem_note: o.problem_note,
               history: o.status_transitions.map { |t| { from: t.from_status, to: t.to_status, at: t.created_at.iso8601, reason: t.reason } },
               payment: o.latest_payment && payment(o.latest_payment), review: o.review && review(o.review, owner: true))
  end

  def payment(p)
    { id: p.id, provider: p.provider, flow: p.flow, status: p.status, amount_cents: p.amount_cents, checkout_url: p.checkout_url, qr_data: p.qr_data,
      qr_svg: p.qr_data.present? ? RQRCode::QRCode.new(p.qr_data).as_svg(module_size: 4, standalone: true, use_path: true) : nil }
  end

  def review(r, owner: false)
    photos = r.visible? ? r.published_photos : r.photos
    base = { id: r.id, rating: r.rating, body: r.body, first_name: r.user.display_name, date: (r.reviewed_at || r.created_at).to_date.iso8601,
             photos: photos.map { |p| { thumb_url: Rendering::Urls.variant_path(p, r.visible? ? :card : :thumb), url: Rendering::Urls.variant_path(p, :large) } },
             product: r.order.items.first&.title }
    owner ? base.merge(status: r.status, rejection_reason: r.rejection_reason, can_resubmit: r.can_resubmit?, coupon: r.coupon && coupon(r.coupon)) : base
  end

  def coupon(c)
    { code: c.code, discount_type: c.discount_type, discount_value: c.discount_value, valid_until: c.valid_until&.iso8601, used: c.exhausted?, valid: c.currently_valid?, min_order_cents: c.min_order_cents }
  end

  def public_settings
    { store_name: Setting.store_name, currency: "ARS", locales: I18n.available_locales.map(&:to_s), default_locale: I18n.default_locale.to_s,
      shipping_methods: Adapters.shipping_methods.map { |m| Adapters.shipping_provider(m).to_h }, rush_enabled: Setting.rush_enabled, rush_fee_cents: Setting.rush_fee_cents,
      max_upload_bytes: Setting.max_upload_bytes, min_upload_px: Setting.min_upload_px, min_dpi: Setting.min_dpi,
      enforce_min_dpi: Setting.enforce_min_dpi, enforce_min_upload_px: Setting.enforce_min_upload_px,
      review_reward_percent: Setting.review_reward_percent, review_window_days: Setting.review_window_days, review_max_photos: Setting.review_max_photos,
      pickup_address: Setting.pickup_address, pickup_hours: Setting.pickup_hours, google_login: ENV["GOOGLE_CLIENT_ID"].present?,
      payment_provider: Adapters.payment_gateway.provider,
      # Development only (see DevCredentials): click-to-fill shortcuts on the login form.
      dev_credentials: DevCredentials.enabled? ? { customers: DevCredentials.customer_list, staff: DevCredentials.staff_list, forced: DevCredentials.forced? } : nil }
  end
end
