require 'prx_auth/rails'

PrxAuth::Rails.configure do |config|
  config.install_middleware = true
  config.namespace = :feeder
  config.id_host = ENV['ID_HOST']
end
