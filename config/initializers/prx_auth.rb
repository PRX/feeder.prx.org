require "prx_auth/rails"

PrxAuth::Rails.configure do |config|
  config.install_middleware = true
  config.namespace = :feeder
  config.id_host = ENV["ID_HOST"]
  config.prx_client_id = ENV["PRX_CLIENT_ID"]
  config.prx_scope = "feeder:* castle:*"
end
