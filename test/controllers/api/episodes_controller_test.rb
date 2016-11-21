require 'test_helper'

describe Api::EpisodesController do
  let(:episode) { create(:episode) }
  let(:podcast) { episode.podcast }

  let(:episode_hash) do
    {
      prxUri: '/api/v1/stories/123'
    }
  end

  it 'should show' do
    episode.id.wont_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: episode.guid } )
    assert_response :success
  end

  it 'should list' do
    episode.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
  end

  it 'should list for podcast' do
    episode.id.wont_be_nil
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json', podcast_id: podcast.id } )
    assert_response :success
  end

  describe 'with a valid token' do
    let(:account_id) { 123 }
    let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
    let(:token) { StubToken.new(account_id, ['member']) }

    before do
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env['CONTENT_TYPE'] = 'application/json'
    end

    it 'can create a new episode' do
      post :create, episode_hash.to_json, api_version: 'v1', format: 'json', podcast_id: podcast.id
      assert_response :success
      guid = JSON.parse(response.body)['guid']
      new_episode = Episode.find_by_guid(guid)
      new_episode.prx_uri.must_equal '/api/v1/stories/123'
    end
  end
end
