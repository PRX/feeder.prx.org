require "prx_access"

class PrxAccessTest
  include PrxAccess
end

describe PrxAccess do
  let(:prx_access) { PrxAccessTest.new }
  let(:resource) { PrxAccess::PrxHyperResource.new }

  it "returns an api" do
    refute_nil prx_access.api
  end

  it "returns root uri" do
    refute_nil prx_access.id_root
    refute_nil prx_access.feeder_root
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
