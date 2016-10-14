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

    config.representer.represented_formats = [:hal, :json]
    config.representer.default_url_options = { host: 'feeder.prx.org' }

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    config.active_job.queue_adapter = :shoryuken
    config.active_job.queue_name_prefix = Rails.env
    config.active_job.queue_name_delimiter = '_'

    config.assets.enabled = false

    config.generators do |g|
      g.assets false
    end
  end
end
