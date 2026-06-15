source "https://rubygems.org"

gem "rails", "~> 7.2.3", ">= 7.2.3.1"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "sprockets-rails"

gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

gem "sidekiq", "~> 7.3"
gem "connection_pool", "~> 3.0"
gem "redis", ">= 4.0.1"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "database_cleaner-active_record"
end

group :development do
  gem "web-console"
end
