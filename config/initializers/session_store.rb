# Be sure to restart your server when you modify this file.

# customized AR-store, which doesn't run SQL on API requests
require "feeder_active_record_store"
Rails.application.config.session_store :feeder_active_record_store, key: "_feeder_session"
