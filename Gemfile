source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

# core
gem "activerecord-session_store"
gem "bootsnap", require: false
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "rails", "~> 7.0.6"
gem "redis", "~> 4.0"

# authorization
gem "oauth2", "~> 1.4.7"
gem "prx_auth"
gem "prx_auth-rails", "~> 4.1.0"
gem "pundit", "~> 2.3.0"
gem "rack-cors"

# html views
gem "active_link_to"
gem "bootstrap", "~> 5.2.2"
gem "importmap-rails"
gem "kaminari"
gem "local_time"
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"
gem "simple_calendar", "~> 2.4"

# api views
gem "actionpack-action_caching" # for hal_api-rails
gem "hal_api-rails", "~> 1.2.0"
gem "jbuilder"
gem "roar-rails", github: "PRX/roar-rails", branch: "feat/rails_7"

# models
gem "addressable"
gem "countries"
gem "paranoia"
gem "sanitize"

# monitoring/logging
gem "lograge"
gem "newrelic_rpm"
gem "ougai"
gem "ougai-formatters-customizable"

# background workers
gem "say_when", "~> 2.2.1"
gem "shoryuken"

# podcast import
gem "feedjira"
gem "loofah"

# utilities
gem "amazing_print"
gem "aws-sdk-sns"
gem "aws-sdk-sqs"
gem "aws-sdk-s3"
gem "excon"
gem "faraday", "~> 0.17.4"
gem "hyperresource"
gem "net-http"
gem "parallel"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "dotenv-rails", "~> 2.0"
  gem "erb_lint", require: false
  gem "pry"
  gem "pry-byebug"
  gem "standard"
end

group :development do
  gem "spring"
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "factory_bot_rails"
  gem "minitest-around"
  gem "minitest-spec-rails"
  gem "minitest-stub_any_instance"
  gem "rails-controller-testing"
  gem "selenium-webdriver"
  gem "simplecov", require: false
  gem "timecop"
  gem "webdrivers"
  gem "webmock"
end
