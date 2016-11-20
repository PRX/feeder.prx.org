require 'test_helper'

describe Api::PodcastsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:token) { StubToken.new(account_id, ['member']) }
  let(:podcast_request) do
    {
      path: 'testcast',
      prx_uri: "/api/v1/series/123",
      prx_account_uri: "/api/v1/accounts/#{account_id}"
    }
  end

  before(:each) do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = token
  end

  it 'rejects create without valid token' do
    @controller.prx_auth_token = nil
    @request.env['CONTENT_TYPE'] = 'application/json'
    post :create, podcast_request.to_json, api_version: 'v1', format: 'json'
    assert_response 401
  end

  it 'can create a new podcast' do
    @request.env['CONTENT_TYPE'] = 'application/json'
    post :create, podcast_request.to_json, api_version: 'v1', format: 'json'
    assert_response :success
  end

  it 'should show' do
    get(:show, { api_version: 'v1', format: 'json', id: podcast.id } )
    assert_response :success
  end

  it 'should list' do
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
  end
end
