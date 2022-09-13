# frozen_string_literal: true

require "test_helper"

describe Apple::ApiResponse do
  let(:ok_http_resp) do
    res = Net::HTTPResponse.new(1.0, 200, "OK")

    res = Net::HTTPOK.new(nil, nil, nil)
    res
  end

  it "returns parsed json from http ok reponses" do
    ok_http_resp.stub(:body, '{"foo": 123}') do
      assert_equal Apple::ApiResponse.json(ok_http_resp), "foo" => 123
    end
  end
end
