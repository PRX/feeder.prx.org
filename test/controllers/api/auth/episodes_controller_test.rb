require 'test_helper'

describe Api::Auth::EpisodesController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:token) { StubToken.new(account_id, ['member']) }
  let(:episode) { create(:episode, podcast: podcast, published_at: nil) }

  before do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = token
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  it 'should show the unpublished episode' do
    episode.id.wont_be_nil
    episode.published_at.must_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: episode.guid } )
    assert_response :success
  end
end
