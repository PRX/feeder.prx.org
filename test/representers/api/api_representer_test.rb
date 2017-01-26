# encoding: utf-8

require 'test_helper'
require 'api' if !defined?(Api)

describe Api::ApiRepresenter do

  let(:api)         { Api.version('1.0') }
  let(:representer) { Api::ApiRepresenter.new(api) }
  let(:json)        { JSON.parse(representer.to_json) }

  it 'create api representer' do
    representer.wont_be_nil
  end

  it 'use api representer to create json' do
    json['version'].must_equal '1.0'
    json.keys.sort.must_equal ['_links', 'version']
  end

  it 'return root doc with links for an api version' do
    json['_links']['self']['href'].must_equal '/api/1.0'
    json['_links']['prx:episode'].size.must_equal 1
    json['_links']['prx:episodes'].size.must_equal 1
    json['_links']['prx:podcast'].size.must_equal 1
    json['_links']['prx:podcasts'].size.must_equal 1
  end
end
