# frozen_string_literal: true

module Apple
  module ApiResponse
    extend ActiveSupport::Concern

    included do
      # assumes the apple_episode_id is present on the request metadata
      def self.join_on_apple_episode_id(resources, results)
        join_on("apple_episode_id", resources, results)
      end

      def self.join_on(id_attribute_key, resources, results)
        resources_by_id = resources.map { |resource| [resource.send(id_attribute_key), resource] }.to_h

        results.map do |row|
          resource = resources_by_id.fetch(row["request_metadata"][id_attribute_key])
          [resource, row]
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
