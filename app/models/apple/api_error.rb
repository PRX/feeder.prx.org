# frozen_string_literal: true

module Apple
  class ApiError < StandardError
    attr_reader :formatted

    def initialize(message, response)
      @formatted = format_message(message, response)
      super(formatted)
    end

    def format_message(message, response)
      "#{message}\n" +
        "HTTP resp code:#{response.try(:code)}\n" +
        response.body.to_s
    end
  end
end
