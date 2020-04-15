require File.expand_path('../boot', __FILE__)

%w(
  active_model
  active_job
  active_record
  action_controller
  action_mailer
  action_view
  rails/test_unit
).each do |framework|
  require "#{framework}/railtie"
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Feeder

  VERSION = '1.0.0'

  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += %W( #{config.root}/app/representers/concerns #{config.root}/app/workers )

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    config.active_job.queue_adapter = :shoryuken
    config.active_job.queue_name_prefix = Rails.env
    config.active_job.queue_name_delimiter = '_'

    config.assets.enabled = false

    config.cache_store = :memory_store, { size: 128.megabytes }

    config.generators do |g|
      g.assets false
    end

    config.middleware.insert_after Rails::Rack::Logger, Rack::Cors do
      allow do
        origins /.*\.prx\.(?:org|dev|tech|docker)$/
        resource '/api/*', methods: [:get, :put, :post, :delete, :options], headers: :any
      end

      allow do
        origins '*'
        resource '/api/*', methods: [:get]
      end
    end

    if ENV['ID_HOST'].present?
      protocol = ENV['ID_HOST'].include?('.docker') ? 'http' : 'https'
      config.middleware.insert_before 'ActionDispatch::ParamsParser', 'Rack::PrxAuth',
                                      cert_location: "#{protocol}://#{ENV['ID_HOST']}/api/v1/certs",
                                      issuer: ENV['ID_HOST']
    end

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.representer.represented_formats = [:hal, :json]
    config.representer.default_url_options = { host: (ENV['FEEDER_HOST'] || 'feeder.prx.org') }

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
  end
end
