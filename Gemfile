source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# core
gem "activerecord-session_store"
gem "bootsnap", require: false
gem "clickhouse-activerecord"
gem "pg", "~> 1.1"
gem "puma", "~> 5.6"
gem "rails", "~> 7.1"

# caching
gem "hiredis", "~> 0.6.3"
gem "redis", "~> 5.0"

# authorization
gem "administrate", "~> 1.0.0.beta3"
gem "oauth2", "~> 1.4.7"
gem "prx_auth-rails", "~> 5.1.0"
gem "pundit", "~> 2.3.0"
gem "rack-cors"

# html views
gem "active_link_to"
gem "bootstrap", "~> 5"
gem "dartsass-rails", "~> 0.5.1"
gem "importmap-rails"
gem "kaminari"
gem "local_time"
gem "propshaft"
gem "stimulus-rails"
gem "turbo-rails"
gem "simple_calendar", "~> 2.4"

# api views
gem "responders"
gem "actionpack-action_caching" # for hal_api-rails
gem "hal_api-rails", "~> 1.2.2"
gem "jbuilder"
gem "roar-rails", github: "PRX/roar-rails", branch: "feat/rails_7"

# models
gem "addressable"
gem "countries"
gem "paranoia"
gem "sanitize"

# monitoring/logging
gem "logger"
gem "lograge"
gem "newrelic_rpm"
gem "ougai"
gem "ougai-formatters-customizable"

# background workers
gem "say_when", "~> 2.2.2"
gem "shoryuken", "~> 6.2.1"

# podcast import
gem "feedjira"
gem "loofah"

# utilities
gem "amazing_print"
gem "aws-sdk-eventbridge"
gem "aws-sdk-sns"
gem "aws-sdk-sqs"
gem "aws-sdk-s3"
gem "csv"
gem "faraday"
gem "link-header-parser", "~> 6.0", ">= 6.0.1"
gem "fiddle"
gem "hyperresource", github: "PRX/hyperresource", branch: "master"
gem "mutex_m"
gem "net-http"
gem "parallel"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails", "~> 2.0"
  gem "erb_lint", require: false
  gem "ostruct"
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
