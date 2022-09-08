# frozen_string_literal: true

module Apple
  class ApiResponse
    attr_reader :http_response

    def self.json(http_response)
      if http_response.class == Net::HTTPOK
        JSON.parse(http_response.body)
      else
        raise Apple::ApiException.new(http_response)
      end
    end
  end
end
