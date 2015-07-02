source 'https://rubygems.org'

# Use Ruby 2.2.2
ruby '2.2.2'

gem 'rails', '4.2.1'
gem 'pg'

gem 'hyperresource'

## Deployment
# configuration
gem 'dotenv-rails'

# scripting
gem 'capistrano', '~> 3.4.0'
gem 'capistrano-rails', '~> 1.1.0'
gem 'highline'
gem 'rake'

# monitoring
gem 'newrelic_rpm'
gem 'capistrano-newrelic'

# sanitizing descriptions
gem 'sanitize'

gem 'paranoia'
gem 'fastimage'

## Messaging
gem 'shoryuken'
gem 'announce'

# Integrations
gem 'fixer_client'
gem 'fog'
gem 'oauth2'

group :test do
  gem 'minitest-spec-rails'
  gem 'factory_girl_rails'
  gem 'simplecov', require: false
  gem 'coveralls', require: false
  gem 'nokogiri'
  gem 'webmock'
  gem 'timecop'
end

group :development, :test do
  gem 'pry-rails'
  gem 'spring'
  gem 'json-jwt'
end

group :development do
  gem 'quiet_assets'
  gem 'better_errors'
  gem 'guard'
  gem 'guard-minitest'
  gem 'guard-bundler'
  gem 'web-console', '~> 2.0'
end
