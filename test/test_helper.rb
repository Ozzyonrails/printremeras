ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module TestImages
  # Generates an in-memory PNG (with alpha) of the given size.
  def png_file(width = 1200, height = 1200, name: "art.png")
    img = Vips::Image.black(width, height, bands: 4).draw_rect([ 200, 40, 40, 255 ], width / 4, height / 4, width / 2, height / 2, fill: true)
    file = Tempfile.new([ name.sub(".png", ""), ".png" ])
    img.write_to_file(file.path)
    file.rewind
    file
  end

  def jpeg_file(width = 1000, height = 1400)
    img = Vips::Image.black(width, height, bands: 3).new_from_image([ 120, 130, 200 ])
    file = Tempfile.new([ "photo", ".jpg" ])
    img.write_to_file(file.path)
    file.rewind
    file
  end

  def upload_blob(file, filename: File.basename(file.path), content_type: "image/png", service_name: ApplicationRecord.private_storage.to_s)
    ActiveStorage::Blob.create_and_upload!(io: File.open(file.path), filename: filename, content_type: content_type, service_name: service_name)
  end
end

module Factories
  def create_template(slug: "remera-#{SecureRandom.hex(2)}", stock: 10)
    tpl = Template.create!(kind: "t-shirt", slug: slug, name_translations: { "es" => "Remera #{slug}", "ru" => "Футболка" }, color_name: "Blanco", color_hex: "#ffffff",
                           base_price_cents: 1_000_000, print_price_one_side_cents: 500_000, print_price_two_sides_cents: 800_000, active: true)
    %w[front back].each do |side|
      area = tpl.print_areas.build(side: side, x: 0.3, y: 0.3, w: 0.4, h: 0.45, width_mm: 280, height_mm: 315, min_dpi: 150, mockup_width_px: 800, mockup_height_px: 950)
      mock = png_file(800, 950, name: "mockup.png")
      area.mockup.attach(io: File.open(mock.path), filename: "mockup.png", content_type: "image/png")
      area.save!
    end
    tpl.template_sizes.create!(label: "M", stock: stock, position: 0)
    tpl.template_sizes.create!(label: "L", stock: stock, position: 1)
    tpl.reload
  end

  def create_user(email: "user#{SecureRandom.hex(2)}@example.com", password: "password123")
    User.create!(email: email, password: password, first_name: "Ana", last_name: "Pérez", confirmed_at: Time.current)
  end

  def create_admin(role: "admin")
    AdminUser.create!(email: "#{role}#{SecureRandom.hex(2)}@example.com", password: "supersecret123", name: role.capitalize, role: role)
  end

  def create_design(owner:, width: 2000, height: 2000, source: "user", license_note: nil)
    blob = upload_blob(png_file(width, height))
    Catalog::CreateDesign.call(owner: owner, signed_blob_id: blob.signed_id, source: source, license_note: license_note).tap { |r| raise r.error_message if r.failure? }.design
  end

  def placement_params(design, area, x: 0.5, y: 0.5, scale: 0.5, rotation: 0)
    { design_id: design.id, print_area_id: area.id, x: x, y: y, scale: scale, rotation: rotation }
  end
end

module EnvSwitching
  # DevCredentials keys off Rails.env at call time, so the cheapest honest way to test
  # both sides is to swap the environment for the duration of the block.
  def with_rails_env(name)
    original = Rails.env
    Rails.env = name.to_s
    yield
  ensure
    Rails.env = original
  end
end

class ActiveSupport::TestCase
  include EnvSwitching
  include TestImages
  include Factories
  include ActiveJob::TestHelper

  parallelize(workers: 1)

  setup do
    Rails.cache.clear
    Setting.bust_cache
    # dotenv loads .env in the test environment too, so a developer's local switches must
    # not decide what the suite proves. Each test starts from the shipped defaults.
    ENV.delete("SHOW_DEV_CREDENTIALS")
    ENV.delete("HIDE_DEV_CREDENTIALS")
    # Rack::Attack counts every request from the same IP, so without this one test's
    # sign-ins throttle the next test's and the suite becomes order-dependent.
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
  end
end

class ActionDispatch::IntegrationTest
  def json = JSON.parse(response.body)

  def api_headers(extra = {})
    { "Accept" => "application/json", "Content-Type" => "application/json", "X-CSRF-Token" => @csrf.to_s }.merge(extra)
  end

  def api(method, path, params = nil, headers: {})
    public_send(method, path, params: params&.to_json, headers: api_headers(headers))
    @csrf = response.headers["X-CSRF-Token"] if response.headers["X-CSRF-Token"]
    response
  end

  def bootstrap_session
    get "/api/v1/session", headers: { "Accept" => "application/json" }
    @csrf = json["csrf_token"]
    json
  end
end
