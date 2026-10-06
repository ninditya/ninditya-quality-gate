# frozen_string_literal: true

# Fail at boot, not on the first invite, when a URL the app hands to users is
# not configured. In development the default points at the local web app.
Rails.application.config.after_initialize do
  if Rails.env.production? && ENV['WEB_BASE_URL'].blank?
    raise 'Missing required environment variable: WEB_BASE_URL ' \
          '(public URL of the web app; candidate invite links are built from it)'
  end
end
