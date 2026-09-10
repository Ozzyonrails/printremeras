require "test_helper"

# R2's S3 endpoint never serves objects anonymously, so an unsigned URL for the public
# bucket produced broken images in the browser. Only advertise public URLs when the bucket
# genuinely has a public address.
class PublicImageUrlTest < ActiveSupport::TestCase
  def with_r2(**env)
    defaults = { "S3_ENDPOINT" => "https://acc.r2.cloudflarestorage.com", "S3_PUBLIC_BUCKET" => "pub",
                 "S3_PRIVATE_BUCKET" => "priv", "S3_ACCESS_KEY_ID" => "k", "S3_SECRET_ACCESS_KEY" => "s" }
    previous = ENV.to_h
    defaults.merge(env).each { |k, v| ENV[k] = v }
    # storage.yml is a flat list of services and reads ENV through ERB, so it is rendered
    # here rather than going through config_for, which scopes by environment.
    config = YAML.load(ERB.new(Rails.root.join("config/storage.yml").read).result, aliases: true).deep_symbolize_keys
    service = ActiveStorage::Service.configure(:s3_public, config)
    yield service
  ensure
    ENV.replace(previous)
  end

  test "without a public address the service is not public, so URLs are signed" do
    with_r2 do |service|
      assert_equal ActiveStorage::Service::R2Service, service.class
      assert_not service.public?
      assert_nil service.upload_options[:acl], "R2 rejects ACL headers"
    end
  end

  test "with a public address the URL points at it instead of the API endpoint" do
    with_r2("S3_PUBLIC_BASE_URL" => "https://pub-abc.r2.dev") do |service|
      assert service.public?
      url = service.url("some-key", filename: ActiveStorage::Filename.new("m.png"))
      assert_equal "https://pub-abc.r2.dev/some-key", url
      assert_no_match "r2.cloudflarestorage.com", url
    end
  end
end
