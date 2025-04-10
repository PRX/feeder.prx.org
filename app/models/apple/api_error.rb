# frozen_string_literal: true

module Apple
  class ApiError < StandardError
    attr_reader :formatted

    def initialize(message, response)
      @formatted = format_message(message, response)
      super(formatted)
    end

    def format_message(message, response)
      resp = "#{message}\n"

      if response.try(:code).present?
        resp += "HTTP resp code:#{response.try(:code)}\n"
      end

      if response.try(:body).present?
        resp += response.body.to_s
      end

      resp
    end

    def self.for_response(message, response)
      begin
        body = JSON.parse(response.body) if response.try(:body).present?

        # Check API key permission error pattern
        if matches_permission_error_pattern?(body)
          return ApiPermissionError.new("Apple API permission error - delegated delivery key lacks required permissions", response)
        end
      rescue JSON::ParserError
        # Fall through to default
      end

      new(message, response)
    end

    def self.matches_permission_error_pattern?(body)
      return false unless body.is_a?(Hash)

      first_error = body&.dig("errors", 0)
      first_error&.dig("code") == "FORBIDDEN_ERROR" &&
        first_error&.dig("detail")&.include?("API key in use does not allow this request")
    end
  end
end
