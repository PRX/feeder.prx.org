require "active_support/concern"

module Megaphone
  module Model
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Model
      attr_accessor :config
      attr_writer :api
      attr_accessor :api_response
    end

    def api
      @api ||= Megaphone::Api.new(token: config.token, network_id: config.network_id)
    end

    def api_response_log_item
      api_response&.slice(:request, :items, :pagination)
    end
  end
end
