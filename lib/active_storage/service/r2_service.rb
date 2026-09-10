require "active_storage/service/s3_service"

module ActiveStorage
  # Cloudflare R2 speaks the S3 API but does not implement object ACLs. Active Storage
  # adds `x-amz-acl: public-read` to every upload for a service declared `public: true`
  # (see S3Service#initialize), which R2 rejects. This subclass is identical to the S3
  # service with that one header removed, so a public bucket works on R2.
  #
  # It also rejects a request that carries more than one checksum, while recent versions of
  # the AWS SDK add a CRC32 header on top of the Content-MD5 Active Storage already sends:
  #   Aws::S3::Errors::InvalidRequest (You can only specify one non-default checksum at a time.)
  # Asking the SDK for checksums only "when_required" leaves just the MD5 and R2 is happy.
  #
  # Selected automatically in config/storage.yml when S3_ENDPOINT points at R2; override
  # with S3_SERVICE=S3 to force the stock behaviour.
  class Service::R2Service < Service::S3Service
    R2_CLIENT_DEFAULTS = {
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required"
    }.freeze

    def initialize(**options)
      super(**R2_CLIENT_DEFAULTS.merge(options))
      upload_options.delete(:acl)
    end
  end
end
