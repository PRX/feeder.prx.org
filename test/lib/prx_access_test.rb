require 'prx_access'

class PRXAccessTest
  include PRXAccess
end

describe PRXAccess do
  let(:prx_access) { PRXAccessTest.new }
  let(:crier_entry) { JSON.parse(json_file(:crier_entry)) }
  let(:resource) { PRXAccess::PRXHyperResource.new }

  it 'returns an api' do
    prx_access.api.wont_be_nil
  end

  it 'returns root uri' do
    prx_access.id_root.wont_be_nil
    prx_access.cms_root.wont_be_nil
    prx_access.crier_root.wont_be_nil
    prx_access.feeder_root.wont_be_nil
  end

  it 'create a resource from json' do
    res = prx_access.api_resource(crier_entry, prx_access.crier_root)
    res.wont_be_nil
    res.attributes['url'] = 'http://traffic.libsyn.com/test/test.mp3'
  end

  it 'underscores incoming hash keys' do
    input = { 'camelCase' => 1 }
    resource.incoming_body_filter(input)['camel_case'].must_equal 1
  end

  it 'underscores outgoing hash keys' do
    input = { 'under_score' => 1 }
    resource.outgoing_body_filter(input)['underScore'].must_equal 1
  end
end
