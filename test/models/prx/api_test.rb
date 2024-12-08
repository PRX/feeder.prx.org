require "test_helper"

class PrxApiTest
  include Prx::Api
end

describe PrxApiTest do
  let(:prx_api) { PrxApiTest.new }
  let(:resource) { Prx::Api::PrxHyperResource.new }

  it "returns an api" do
    refute_nil prx_api.api
  end

  it "returns root uri" do
    refute_nil prx_api.id_root
    refute_nil prx_api.feeder_root
  end

  it "underscores incoming hash keys" do
    input = {"camelCase" => 1}
    assert_equal resource.incoming_body_filter(input)["camel_case"], 1
  end

  it "underscores outgoing hash keys" do
    input = {"under_score" => 1}
    assert_equal resource.outgoing_body_filter(input)["underScore"], 1
  end
end
