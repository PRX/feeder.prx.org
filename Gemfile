source 'https://rubygems.org'

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

group :test do
  gem 'minitest-spec-rails'
  gem 'minitest-reporters', require: false
  gem 'minitest-focus'
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
end

group :development do
  gem 'quiet_assets'
  gem 'better_errors'
  gem 'guard'
  gem 'guard-minitest'
  gem 'guard-bundler'
  gem 'web-console', '~> 2.0'
end
