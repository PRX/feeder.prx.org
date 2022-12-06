source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.5'

##### app gems
gem 'prx_auth-rails', '~> 3.0.1'
gem 'prx_auth'

gem 'roar-rails', github: 'PRX/roar-rails', branch: 'feat/rails_7'
gem 'hal_api-rails', '~> 1.2.0'

# auth
gem 'rack-cors'
gem 'pundit', '~> 2.0.0'

# paging
gem 'kaminari'

# caching
gem 'actionpack-action_caching'

# Use Shoryuken for processing SQS jobs
gem 'shoryuken'

# Use SayWhen for scheduling tasks
gem 'say_when', '~> 2.2.0'

# Use HyperResource for handling HAL APIs
gem 'hyperresource'

# Use OAuth2 for client authentication and authorization
gem 'oauth2', '~> 1.4.7'
gem 'excon'

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

# for validating media:restriction codes
gem 'countries'

gem 'aws-sdk-sns'
gem 'aws-sdk-sqs'
gem 'aws-sdk-s3'

gem 'ougai'
gem 'ougai-formatters-customizable'
gem 'lograge'
gem 'amazing_print'

#####

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.0.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 5.0'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.0'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# # Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Sass to process CSS
# gem "sassc-rails"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'dotenv-rails', '~> 2.0'
  gem 'pry'
  gem 'pry-byebug'
  gem 'rubocop'
  gem 'rubocop-performance', '~> 1.4'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  gem "spring"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'webdrivers'

  gem 'rails-controller-testing'
  gem 'factory_bot_rails'
  gem 'minitest-spec-rails'
  gem 'minitest-around'
  gem 'webmock'
  gem 'simplecov', require: false
  gem 'timecop'
end
