module Reviews
  # Subscriber to review_approved: copy photos from the private bucket to the public one.
  class PublishPhotos
    def self.call(event:, payload:)
      review = Review.find(payload[:review_id])
      return if review.published_photos.attached? || !review.approved?

      review.photos.each do |photo|
        copy = Storage::CopyBlob.call(blob: photo.blob, to_service: ApplicationRecord.public_storage)
        review.published_photos.attach(copy.blob)
      end
    end
  end
end
