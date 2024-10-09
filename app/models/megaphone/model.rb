module Megaphone
  class Model
    include ActiveModel::Model
    attr_accessor :feed
    attr_writer :api

    def config
      feed.megaphone_config
    end

    def api
      @api ||= Megaphone::Api.new(token: config.token, network_id: config.network_id)
    end
  end
end
