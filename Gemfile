source 'https://rubygems.org'
ruby '2.2.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

# Use Postresql as the database for Active Record
gem 'pg'

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
# gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Use Shoryuken for processing SQS jobs
gem 'shoryuken'
# Use Announce for event subscriptions
gem 'announce'

# Use HyperResource for handling HAL APIs
gem 'hyperresource'
# Use fog for working with cloud services
gem 'fog'
# Use Fixer client for handling audio processing
gem 'fixer_client'

# Monitor app performance with NewRelic
gem 'newrelic_rpm'

# sanitizing descriptions
gem 'sanitize'

# Paranoia allows Active Record objects to be soft deleted
gem 'paranoia'

# FastImage finds the size or type of an image given its uri
gem 'fastimage'

gem 'oauth2'

group :development do
  # Use Capistrano for deployment
  # gem 'capistrano-rails', '~> 1.1.0'
  # Add NewRelic support to Capistrano deployments
  # gem 'capistrano-newrelic'

  # Quiet Assets turns off Rails asset pipeline log
  gem 'quiet_assets'

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
  gem 'minitest-spec-rails'
  gem 'factory_girl_rails'
  gem 'simplecov', require: false
  gem 'coveralls', require: false
  gem 'nokogiri'
  gem 'webmock'
  gem 'timecop'
end

group :development, :test do
  gem 'json-jwt'

  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'

  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Load local environment variables with dotenv
  gem 'dotenv-rails'

  # Pry is an IRB alternative and runtime developer console
  gem 'pry-rails'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end
