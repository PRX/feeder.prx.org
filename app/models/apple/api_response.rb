# frozen_string_literal: true

module Apple
  module ApiResponse
    extend ActiveSupport::Concern

    included do
      # assumes the
      def self.zip_result_with_episode(result, eps)
        episodes_by_id = eps.map { |ep| [ep.apple_id, ep] }.to_h

        result.map do |row|
          ep = episodes_by_id.fetch(row["request_metaapple_data"]["apple_episode_id"])
          [ep, row]
        end
      end
    end

    def unwrap_response
      raise "incomplete api response" unless api_response && api_response.dig("api_response", "ok")

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
      apple_data["id"]
    end
  end
end
