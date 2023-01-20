require "prx_access"

class PrxAccessTest
  include PrxAccess
end

describe PrxAccess do
  let(:prx_access) { PrxAccessTest.new }
  let(:crier_entry) { JSON.parse(json_file(:crier_entry)) }
  let(:resource) { PrxAccess::PrxHyperResource.new }

  it "returns an api" do
    refute_nil prx_access.api
  end

  it "returns root uri" do
    refute_nil prx_access.id_root
    refute_nil prx_access.cms_root
    refute_nil prx_access.crier_root
    refute_nil prx_access.feeder_root
  end

  it "create a resource from json" do
    res = prx_access.api_resource(crier_entry, prx_access.crier_root)
    refute_nil res
    res.attributes["url"] = "http://traffic.libsyn.com/test/test.mp3"
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
