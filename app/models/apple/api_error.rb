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
        response.body.to_s
      end

      resp
    end
  end
end
