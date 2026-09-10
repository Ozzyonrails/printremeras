# Idempotent seeds: an admin user, an operator, and (in development) demo templates.
require "vips"

creds = DevCredentials.admin
admin = AdminUser.find_or_initialize_by(email: creds[:email])
admin.assign_attributes(name: creds[:name], role: "admin", password: creds[:password]) if admin.new_record?
admin.save!
puts "Admin user: #{admin.email} (role admin)"

if Rails.env.development? || ENV["SEED_DEMO"] == "true"
  op = DevCredentials::OPERATOR
  operator = AdminUser.find_or_initialize_by(email: op[:email])
  operator.assign_attributes(name: op[:name], role: "operator", password: op[:password]) if operator.new_record?
  operator.save!

  # A demo customer so the storefront login shortcut has a real account behind it.
  cust = DevCredentials::CUSTOMER
  customer = User.find_or_initialize_by(email: cust[:email])
  if customer.new_record?
    customer.assign_attributes(password: cust[:password], first_name: cust[:first_name], last_name: cust[:last_name],
                               phone: "+54 11 5555 5555", locale: "es", confirmed_at: Time.current)
  end
  customer.save!
  customer.addresses.find_or_create_by!(street: "Av. Corrientes", number: "1234") do |a|
    a.assign_attributes(recipient_name: customer.full_name, phone: customer.phone, neighborhood: "San Nicolás",
                        postal_code: "C1043", city: "CABA", is_default: true)
  end

  # Generates a simple flat garment mockup so the editor works without real photos.
  def make_mockup(color_hex, width = 1600, height = 1900)
    rgb = color_hex.delete("#").scan(/../).map { |c| c.to_i(16) }
    img = Vips::Image.black(width, height, bands: 3).new_from_image([ 245, 245, 247 ])
    body = Vips::Image.black(width, height, bands: 3).new_from_image(rgb)
    mask = Vips::Image.black(width, height)
    # torso rectangle + sleeves, drawn with draw_rect (approximate garment silhouette)
    mask = mask.draw_rect(255, (width * 0.22).to_i, (height * 0.2).to_i, (width * 0.56).to_i, (height * 0.72).to_i, fill: true)
    mask = mask.draw_rect(255, (width * 0.06).to_i, (height * 0.2).to_i, (width * 0.88).to_i, (height * 0.22).to_i, fill: true)
    mask = mask.draw_circle(255, (width * 0.5).to_i, (height * 0.2).to_i, (width * 0.12).to_i, fill: true)
    result = mask.ifthenelse(body, img)
    file = Tempfile.new([ "mockup", ".png" ])
    result.write_to_file(file.path)
    file
  end

  demo = [
    { slug: "remera-blanca", kind: "t-shirt", name: { "es" => "Remera básica blanca", "ru" => "Белая базовая футболка" }, color_name: "Blanco", color_hex: "#f4f4f4", base: 1_200_000, one: 600_000, two: 950_000 },
    { slug: "remera-negra", kind: "t-shirt", name: { "es" => "Remera básica negra", "ru" => "Чёрная базовая футболка" }, color_name: "Negro", color_hex: "#1f1f1f", base: 1_200_000, one: 650_000, two: 1_000_000 },
    { slug: "buzo-gris", kind: "hoodie", name: { "es" => "Buzo con capucha gris", "ru" => "Серое худи" }, color_name: "Gris", color_hex: "#8a8f98", base: 3_500_000, one: 900_000, two: 1_500_000 }
  ]
  demo.each_with_index do |d, i|
    tpl = Template.find_or_initialize_by(slug: d[:slug])
    tpl.assign_attributes(kind: d[:kind], name_translations: d[:name], description_translations: { "es" => "100% algodón peinado, 24/1.", "ru" => "100% хлопок, 24/1." },
                          color_name: d[:color_name], color_hex: d[:color_hex], base_price_cents: d[:base], print_price_one_side_cents: d[:one],
                          print_price_two_sides_cents: d[:two], active: true, position: i)
    tpl.save!
    %w[front back].each do |side|
      area = tpl.print_areas.find_or_initialize_by(side: side)
      area.assign_attributes(x: 0.3, y: 0.3, w: 0.4, h: 0.45, width_mm: 280, height_mm: 315, min_dpi: 150)
      unless area.mockup.attached?
        file = make_mockup(d[:color_hex])
        area.mockup.attach(io: File.open(file.path), filename: "#{d[:slug]}-#{side}.png", content_type: "image/png")
        area.mockup_width_px = 1600
        area.mockup_height_px = 1900
      end
      area.save!
    end
    %w[S M L XL XXL].each_with_index do |label, pos|
      size = tpl.template_sizes.find_or_initialize_by(label: label)
      size.assign_attributes(stock: size.new_record? ? (label == "XXL" ? 0 : 25) : size.stock, position: pos, restock_at: label == "XXL" && size.new_record? ? 2.weeks.from_now.to_date : size.restock_at)
      size.save!
    end
  end
  puts "Demo templates: #{Template.count}"
  puts "Sign in with:"
  (DevCredentials.staff_accounts + DevCredentials.customer_accounts).each do |a|
    puts "  #{a[:email]} / #{a[:password]}#{a[:role] ? " (#{a[:role]})" : " (customer)"}"
  end
end
