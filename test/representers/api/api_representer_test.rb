# encoding: utf-8

require 'test_helper'
require 'api' if !defined?(Api)

describe Api::ApiRepresenter do

  let(:api)         { Api.version('1.0') }
  let(:representer) { Api::ApiRepresenter.new(api) }
  let(:json)        { JSON.parse(representer.to_json) }

  it 'create api representer' do
    refute_nil representer
  end

  it 'use api representer to create json' do
    assert_equal json['version'], '1.0'
    assert_equal json.keys.sort, ['_links', 'version']
  end

  it 'return root doc with links for an api version' do
    assert_equal json['_links']['self']['href'], '/api/1.0'
    assert_equal json['_links']['prx:episode'].size, 1
    assert_equal json['_links']['prx:episodes'].size, 1
    assert_equal json['_links']['prx:podcast'].size, 1
    assert_equal json['_links']['prx:podcasts'].size, 1
    assert_instance_of Hash, json['_links']['prx:authorization']
  end
end
