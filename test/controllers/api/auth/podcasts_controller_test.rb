require 'test_helper'

describe Api::Auth::PodcastsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", published_at: nil) }
  let(:token) { StubToken.new(account_id, ['member']) }

  before do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = token
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  it 'should show the unpublished podcast' do
    podcast.id.wont_be_nil
    podcast.published_at.must_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: podcast.id } )
    assert_response :success
  end
end
