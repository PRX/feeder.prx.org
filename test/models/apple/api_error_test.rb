# frozen_string_literal: true

require "test_helper"

describe Apple::ApiError do
  describe ".initialize" do
    it "should construct an exception object with a message and response object" do
      response = OpenStruct.new(code: 200, body: "body")
      exception = Apple::ApiError.new("message", response)

      assert_equal exception.message, "message\nHTTP resp code:200\nbody"
    end
  end

  describe ".for_response" do
    it "returns a regular ApiError for normal errors" do
      response = OpenStruct.new(code: 404, body: '{"errors":[{"status": "404", "code": "NOT_FOUND"}]}')
      exception = Apple::ApiError.for_response("Apple API Error", response)

      assert_instance_of Apple::ApiError, exception
      assert_equal "Apple API Error\nHTTP resp code:404\n{\"errors\":[{\"status\": \"404\", \"code\": \"NOT_FOUND\"}]}", exception.message
    end

    it "returns an ApiPermissionError for API key permission errors" do
      permission_error_body = {
        errors: [
          {
            id: "88258fa2-8d8c-46ff-b3a6-80a650ef9ed4",
            status: "403",
            code: "FORBIDDEN_ERROR",
            title: "This request is forbidden for security reasons",
            detail: "The API key in use does not allow this request"
          }
        ]
      }.to_json

      response = OpenStruct.new(code: 403, body: permission_error_body)
      exception = Apple::ApiError.for_response("Apple API Error", response)

      assert_instance_of Apple::ApiPermissionError, exception
      assert exception.message.include?("Apple API permission error")
    end

    it "handles invalid JSON responses" do
      response = OpenStruct.new(code: 500, body: "<html>Internal Server Error</html>")
      exception = Apple::ApiError.for_response("Apple API Error", response)

      assert_instance_of Apple::ApiError, exception
      assert_equal "Apple API Error\nHTTP resp code:500\n<html>Internal Server Error</html>", exception.message
    end
  end
end
