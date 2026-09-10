module AdminHelper
  def money(cents, currency = "ARS") = Money.format(cents, currency: currency)

  def status_badge(status)
    tag.span t("orders.statuses.#{status}", default: status.to_s.humanize), class: "badge badge-#{status}"
  end

  def review_badge(status) = tag.span(t("reviews.statuses.#{status}"), class: "badge badge-review-#{status}")

  def nav_link(label, path, count: nil, active: nil)
    active = current_page?(path) || request.path.start_with?(path) && path != admin_root_path if active.nil?
    link_to path, class: "nav-link #{'active' if active}" do
      safe_join([ label, (count.to_i.positive? ? tag.span(count, class: "nav-count") : nil) ].compact, " ")
    end
  end

  def pagination
    return if @pages.to_i <= 1
    tag.nav(class: "pagination") do
      safe_join((1..@pages).map { |p| link_to p, url_for(request.query_parameters.merge(page: p)), class: (p == [ params[:page].to_i, 1 ].max ? "active" : "") })
    end
  end

  def transition_label(status) = t("orders.statuses.#{status}")

  def image_or_placeholder(attachment, variant, **opts)
    present = attachment.respond_to?(:attached?) ? attachment.attached? : attachment.present?
    if present
      image_tag rails_representation_path(attachment.variant(variant)), **opts
    else
      tag.div(class: "img-placeholder #{opts[:class]}")
    end
  rescue ActiveStorage::InvariableError
    image_tag rails_blob_path(attachment), **opts
  end

  # CSS-only composite of a placement on its mockup (same math as the editor). Used by the
  # moderation queue so staff can see the design in context before payment/rendering.
  def placement_preview(placement, width: 320)
    area = placement.print_area
    design = placement.design
    return tag.div(class: "img-placeholder") unless area.mockup.attached? && design.file.attached?
    art_w_pct = placement.scale.to_f * 100
    tag.div(class: "placement-preview", style: "width:#{width}px") do
      concat image_tag(rails_representation_path(area.mockup.variant(:editor)), style: "width:100%;display:block", alt: "")
      concat tag.div(style: "position:absolute;left:#{area.x.to_f * 100}%;top:#{area.y.to_f * 100}%;width:#{area.w.to_f * 100}%;height:#{area.h.to_f * 100}%;overflow:hidden;outline:1px dashed rgba(0,0,0,.3)") {
        image_tag(rails_blob_path(design.file), style: "position:absolute;left:#{placement.x.to_f * 100}%;top:#{placement.y.to_f * 100}%;width:#{art_w_pct}%;transform:translate(-50%,-50%) rotate(#{placement.rotation.to_f}deg);transform-origin:center;max-width:none", alt: "")
      }
    end
  end

  def setting_field(key, spec, value)
    name = "settings[#{key}]"
    case spec[:type]
    when :boolean
      safe_join([ hidden_field_tag(name, "0", id: nil), check_box_tag(name, "1", value, id: "setting_#{key}") ])
    when :integer then number_field_tag(name, value, id: "setting_#{key}", class: "input")
    when :json then text_area_tag(name, JSON.pretty_generate(value || {}), id: "setting_#{key}", class: "input mono", rows: 4)
    when :secret then password_field_tag(name, "", id: "setting_#{key}", class: "input", placeholder: value.present? ? "••••••••  (#{t('admin.settings.keep')})" : "")
    else text_field_tag(name, value, id: "setting_#{key}", class: "input")
    end
  end
end
