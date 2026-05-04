# frozen_string_literal: true

module Apple
  module ApiResponse
    extend ActiveSupport::Concern

    def api_response
      apple_sync_log&.api_response
    end

    def guard_for_ok_response
      return true if api_response&.dig("api_response", "ok")

      sl = try(:apple_sync_log)
      Rails.logger.error("Apple api response error", apple_sync_log: sl&.as_json, this_class: self.class.name, this: try(:id))

      raise "incomplete api response"
    end

    def unwrap_response
      guard_for_ok_response

      api_response["api_response"]["val"]
    end

    def apple_attributes
      apple_data["attributes"]
    end

    def apple_data
      unwrap_response["data"]
    end

    def apple_type
      apple_data["type"]
    end

    def apple_id
      raise "missing apple id" unless apple_data["id"].present?

      apple_data["id"]
    end
  end
end
