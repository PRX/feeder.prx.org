require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Feeder
  VERSION = '1.0.0'.freeze
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += %W(
      #{config.root}/app/models/validators
      #{config.root}/app/representers/concerns
      #{config.root}/app/workers
    )

    # Use Rails 7 zeitwerk eager loading
    config.eager_load_paths += %W(
      #{config.root}/app/models/validators
      #{config.root}/app/representers/concerns
      #{config.root}/app/workers
    )

    # # Do not swallow errors in after_commit/after_rollback callbacks.
    # config.active_record.raise_in_transactional_callbacks = true

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.action_controller.forgery_protection_origin_check = false

    config.active_job.queue_adapter = :shoryuken
    config.active_job.queue_name_prefix = ENV['ANNOUNCE_RESOURCE_PREFIX'] || ENV['RAILS_ENV']
    config.active_job.queue_name_delimiter = '_'

    config.cache_store = :memory_store, { size: 128.megabytes }

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    # health check path
    class HealthCheckMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        if env['PATH_INFO'] == '/health_check'
          [200, {'Content-Type' => 'text/plain'}, ['ok']]
        else
          @app.call(env)
        end
      end
    end
    config.middleware.insert_before Rails::Rack::Logger, HealthCheckMiddleware

    config.middleware.insert_after Rails::Rack::Logger, Rack::Cors do
      allow do
        origins /.*\.prx\.(?:org|dev|test|tech|docker)$/
        resource '/api/*', methods: [:get, :put, :post, :delete, :options], headers: :any
      end

      allow do
        origins '*'
        resource '/api/*', methods: [:get]
      end
    end

    # prx_auth-rails
    if ENV['ID_HOST'].present?
      protocol = ENV['ID_HOST'].include?('.docker') ? 'http' : 'https'
      config.middleware.insert_after Rack::Head, Rack::PrxAuth,
                                     cert_location: "#{protocol}://#{ENV['ID_HOST']}/api/v1/certs",
                                     issuer: ENV['ID_HOST']
    end

    config.representer.represented_formats = [:hal, :json]
    config.representer.default_url_options = { host: (ENV['FEEDER_HOST'] || 'feeder.prx.org') }

    # Logging
    module ActiveSupport::TaggedLogging::Formatter
      def call(severity, time, progname, data)
        data = { msg: data.to_s } unless data.is_a?(Hash)
        tags = current_tags
        data[:tags] = tags if tags.present?
        _call(severity, time, progname, data)
      end
    end

    require "#{Rails.root}/lib/feeder_logger.rb"
    config.logger = ActiveSupport::TaggedLogging.new(FeederLogger.new($stdout))

    # Used when invoking the async workers via supervisord.
    if ENV['USE_SYNC_STDOUT'].present?
      $stdout.sync = true
    end

    config.lograge.enabled = true
    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)
      {
        user_id: event.payload[:request].session.dig('prx.auth.info', 'sub'),
        params: event.payload[:params].except(*exceptions)
      }
    end

    config.lograge.formatter = Class.new do |fmt|
      def fmt.call(data)
        { msg: 'Request', request: data }
      end
    end

    config.log_tags = [:request_id]
    config.active_record.schema_format = :ruby

  end
end
