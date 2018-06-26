source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.0'
gem 'rails-html-sanitizer', '~> 1.0.4'

# JWS
gem 'prx_auth-rails', '~> 0.0.4'
gem 'rack-prx_auth', '~> 0.0.8'

# Controller
gem 'responders'
gem 'hal_api-rails', '~> 0.2.9'

# auth
gem 'rack-cors', require: 'rack/cors'
gem 'pundit'

# paging
gem 'kaminari'

# caching
gem 'actionpack-action_caching'


## View
# json handling
gem 'roar'
gem 'roar-rails'
# gem 'oj'
# gem 'oj_mimic_json'

# Use Shoryuken for processing SQS jobs
gem 'shoryuken'
# Use Announce for event subscriptions
gem 'announce'

gem 'say_when', '~> 2.0'

# Load local environment variables with dotenv
gem 'dotenv-rails'


# Use Postresql as the database for Active Record
gem 'pg'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'rake'

# Use HyperResource for handling HAL APIs
gem 'hyperresource'
# Use Fixer client for handling audio processing
gem 'fixer_client'

# Use OAuth2 for client authentication and authorization
gem 'oauth2'

# Monitor app performance with NewRelic
gem 'newrelic_rpm'

# Use Sanitize for HTML and CSS whitelisting
gem 'sanitize'

# Paranoia allows Active Record objects to be soft deleted
gem 'paranoia'

# FastImage finds the size or type of an image given its uri
gem 'fastimage'

# for url templates
gem 'addressable'

gem 'aws-sdk'

group :development, :test do
  # Pry is an IRB alternative and runtime developer console
  gem 'pry-rails'
  gem 'pry-byebug'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  # Use JSON Web Token for signing and encrypting
  gem 'json-jwt'
end

group :development do
  # Use Capistrano for deployment
  # gem 'capistrano-rails', '~> 1.1.0'
  # Add NewRelic support to Capistrano deployments
  # gem 'capistrano-newrelic'

  # HighLine is a higher level command-line oriented interface
  gem 'highline'

  # Guard handles events on file system modifications
  gem 'guard'
  # Automatically run your tests with Minitest framework
  gem 'guard-minitest'
  # Automatically install/update your gem bundle when needed
  gem 'guard-bundler'
end

group :test do
  # Add rspec behaviour to minitest
  gem 'minitest-spec-rails'

  # factory_girl provides a DSL for defining and using factories
  gem 'factory_girl_rails'

  # SimpleCov is a code coverage analysis tool for Ruby
  gem 'simplecov', require: false

  # Coveralls is a service that tracks test coverage
  gem 'coveralls', require: false

  # Use Nokogiri for XML and HTML parsing
  gem 'nokogiri'

  # WebMock allows stubbing HTTP requests
  gem 'webmock'

  # Making it dead simple to test time-dependent code
  gem 'timecop'

  gem 'rubocop', require: false
end

group :development, :staging, :production do
  # Include 'rails_12factor' gem so all logs go to stdout, etc.
  gem 'rails_12factor'

  # Use puma as the HTTP server
  gem 'puma'
end
