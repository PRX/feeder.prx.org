# frozen_string_literal: true

require 'test_helper'

describe Apple::ApiError do

  describe '.initialize' do
    it 'should construct an exception object with a message and response object' do
      response = OpenStruct.new(code: 200, body: 'body')
      exception = Apple::ApiError.new('message', response)

      assert_equal exception.message, "message\nHTTP resp code:200\nbody"
    end
  end
end
