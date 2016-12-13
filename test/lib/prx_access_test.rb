require 'prx_access'

class PRXAccessTest
  include PRXAccess
end

describe PRXAccess do
  let(:prx_access) { PRXAccessTest.new }
  let(:crier_entry) { JSON.parse(json_file(:crier_entry)) }

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
end
