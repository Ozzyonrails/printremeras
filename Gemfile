source "https://rubygems.org"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Auth
gem "bcrypt", "~> 3.1.7"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# Infra: database-backed adapters for Rails.cache, Active Job and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "mission_control-jobs"

gem "bootsnap", require: false
gem "thruster", require: false

# Storage & images
gem "image_processing", "~> 2.1"
# Loaded on demand: initialising libvips (and glib's threads) at boot makes forked
# children (Solid Queue) crash on macOS. Renderers require "vips" themselves.
gem "ruby-vips", require: false
gem "aws-sdk-s3", require: false
gem "marcel"
gem "rubyzip", require: "zip"

# API / security
gem "rack-cors"
gem "rack-attack"
gem "rqrcode"
gem "rails-i18n"
gem "json", "~> 2.10"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "dotenv-rails"
  gem "letter_opener"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
end
