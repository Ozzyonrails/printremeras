# Announce loudly when the sign-in shortcuts are on outside development, so a container
# that was started with SHOW_DEV_CREDENTIALS=true by accident is obvious in the logs.
Rails.application.config.after_initialize do
  if DevCredentials.forced?
    Rails.logger.warn("[dev-credentials] SHOW_DEV_CREDENTIALS is on in #{Rails.env}: demo passwords are visible on the login screens. Unset it for a public deployment.")
  end
end
