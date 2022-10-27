source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.11.3'
gem 'rails-html-sanitizer', '~> 1.4.3'

# JWS
gem 'prx_auth-rails', '~> 1.2.0'

# TODO merge this into PRX auth rails
gem 'jwt'

# Controller
gem 'responders'
gem 'hal_api-rails', '~> 0.3.7'

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
gem 'announce', '~> 0.3.0'

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

# Use OAuth2 for client authentication and authorization
gem 'oauth2'
gem 'excon'

# Monitor app performance with NewRelic
gem 'newrelic_rpm'

# Monitor app performance with OpenTelemetry services
gem 'opentelemetry-sdk'
gem 'opentelemetry-exporter-otlp'
gem 'opentelemetry-instrumentation-all'

# Use Sanitize for HTML and CSS whitelisting
gem 'sanitize'

# Paranoia allows Active Record objects to be soft deleted
gem 'paranoia'

# FastImage finds the size or type of an image given its uri
gem 'fastimage'

# for url templates
gem 'addressable'

# for validating media:restriction codes
gem 'countries'

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

  gem 'm'
end

group :test do
  # Add rspec behaviour to minitest
  gem 'minitest-spec-rails'
  gem 'minitest-around'

  # factory_girl provides a DSL for defining and using factories
  gem 'factory_girl_rails'

  # SimpleCov is a code coverage analysis tool for Ruby
  gem 'simplecov', require: false

  # Coveralls is a service that tracks test coverage
  gem 'coveralls', require: false

  # Use Nokogiri for XML and HTML parsing
  gem 'nokogiri', '>= 1.10.4'

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
