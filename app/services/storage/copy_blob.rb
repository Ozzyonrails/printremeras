module Storage
  # ActiveStorage cannot move a blob between services; we copy the bytes into a new
  # blob on the target service. The caller re-attaches and purges the original.
  class CopyBlob < ApplicationService
    def initialize(blob:, to_service:)
      @blob = blob
      @to_service = to_service
    end

    def call
      new_blob = @blob.open do |file|
        ActiveStorage::Blob.create_and_upload!(io: file, filename: @blob.filename, content_type: @blob.content_type,
                                               metadata: @blob.metadata, service_name: @to_service.to_s, identify: false)
      end
      success(blob: new_blob)
    end
  end
end
