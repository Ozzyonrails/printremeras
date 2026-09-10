# Signed URLs for the private bucket expire quickly.
Rails.application.config.active_storage.service_urls_expire_in = 15.minutes
Rails.application.config.active_storage.urls_expire_in = 15.minutes
Rails.application.config.active_storage.content_types_to_serve_as_binary += [ "image/svg+xml" ]
