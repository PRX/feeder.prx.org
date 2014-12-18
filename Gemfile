source 'https://rubygems.org'

gem 'rails', '4.1.5'
gem 'mysql2'

## Deployment
# configuration
gem 'dotenv-rails'

# scripting
gem 'capistrano', '~> 3.2.0'
gem 'capistrano-rails', '~> 1.1.0'
gem 'highline'
gem 'rake'

# monitoring
gem 'newrelic_rpm'
gem 'capistrano-newrelic'

group :test do
  gem 'minitest-spec-rails'
  gem 'minitest-reporters', require: false
  gem 'factory_girl_rails'
  gem "codeclimate-test-reporter", require: false
  gem 'simplecov', '~> 0.7.1', require: false
  gem 'coveralls', require: false
  gem 'test_xml', require: false
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
end
