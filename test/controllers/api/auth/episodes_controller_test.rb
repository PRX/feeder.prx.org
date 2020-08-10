require 'test_helper'

describe Api::Auth::EpisodesController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:token) { StubToken.new(account_id, ['member']) }
  let(:episode) { create(:episode, podcast: podcast) }

  let(:different_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: 'diff') }
  let(:episode_different_podcast) { create(:episode, podcast: different_podcast) }

  let(:episode_unpublished) { create(:episode, podcast: podcast, published_at: nil) }
  let(:episode_deleted) { create(:episode, deleted_at: Time.now, podcast: podcast) }
  let(:episode_hash) do
    {
      releasedAt: '2020-03-12T18:02:03.000Z',
      prxUri: '/api/v1/stories/123',
      media: [
        { href: 'https://s3.amazonaws.com/prx-testing/test/audio1.mp3' },
        { href: 'https://s3.amazonaws.com/prx-testing/test/audio2.mp3' },
        { href: 'https://s3.amazonaws.com/prx-testing/test/audio3.mp3' }
      ]
    }
  end

  before do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = token
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  it 'should show the unpublished episode' do
    episode_unpublished.id.wont_be_nil
    episode_unpublished.published_at.must_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: episode_unpublished.guid } )
    assert_response :success
  end

  it 'should show' do
    episode.id.wont_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: episode.guid } )
    assert_response :success
  end

  it 'should return resource gone for deleted resource' do
    episode_deleted.id.wont_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: episode_deleted.guid } )
    assert_response 410
  end

  it 'should return not found for unknown resource' do
    episode_deleted.id.wont_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: 'thisismadeup' } )
    assert_response 404
  end

  it 'should list' do
    episode.id.wont_be_nil
    episode_unpublished.id.wont_be_nil
    episode_unpublished.published_at.must_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
    list = JSON.parse(response.body)
    ids = list.dig('_embedded', 'prx:items').map{ |i| i['id'] }
    ids.must_include(episode.guid)
    ids.must_include(episode_unpublished.guid)
  end

  it 'should list for podcast' do
    episode.id.wont_be_nil
    podcast.id.wont_be_nil
    episode_different_podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json', podcast_id: podcast.id } )
    assert_response :success
    body = JSON.parse(response.body)
    ids = body['_embedded']['prx:items'].map { |s| s['id'] }
    ids.count.must_equal 1
    ids.wont_include episode_different_podcast.guid
  end

  describe 'with a valid token' do
    let(:account_id) { 123 }
    let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
    let(:episode_redirect) { create(:episode, podcast: podcast, published_at: nil) }
    let(:episode_update) { create(:episode, podcast: podcast, published_at: nil) }
    let(:token) { StubToken.new(account_id, ['member']) }

    before do
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env['CONTENT_TYPE'] = 'application/json'
    end

    it 'can create a new episode' do
      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          post :create, episode_hash.to_json, api_version: 'v1', format: 'json', podcast_id: podcast.id
        end
      end
      assert_response :success
      id = JSON.parse(response.body)['id']
      new_episode = Episode.find_by_guid(id)
      new_episode.released_at.must_equal Time.parse(episode_hash[:releasedAt])
      new_episode.prx_uri.must_equal '/api/v1/stories/123'
      new_episode.enclosures.count.must_equal 0
      new_episode.all_contents.count.must_equal 3
      c = new_episode.all_contents.first
      c.original_url.must_equal 'https://s3.amazonaws.com/prx-testing/test/audio1.mp3'
    end

    it 'can update audio on an episode' do
      update_hash = { media: [{ href: 'https://s3.amazonaws.com/prx-testing/test/change1.mp3' }] }

      episode_update.all_contents.size.must_equal 0

      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          put :update, update_hash.to_json, id: episode_update.guid, api_version: 'v1', format: 'json'
        end
      end
      assert_response :success

      episode_update.reload.all_contents.size.must_equal 1

      # updating with a dupe should insert it, with the same position value of 1
      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          put :update, update_hash.to_json, id: episode_update.guid, api_version: 'v1', format: 'json'
        end
      end
      assert_response :success

      episode_update.reload.all_contents.size.must_equal 2
      episode_update.all_contents.first.position.must_equal 1
      episode_update.all_contents.last.position.must_equal 1
    end
  end

  describe 'with wildcard token' do
    let (:token) { StubToken.new('*', ['read-private']) }
    let (:other_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id + 1}", path: 'foo') }
    let (:other_unpublished_episode) { create(:episode, podcast: other_podcast, published_at: nil) }

    it 'includes all episodes (including unpublished)' do
      guids = [episode_unpublished.guid, other_unpublished_episode.guid]
      get(:index, { api_version: 'v1', format: 'json' } )
      assert_response :success
      list = JSON.parse(response.body)
      ids = list.dig('_embedded', 'prx:items').map{ |i| i['id'] }
      guids.each do |guid|
        ids.must_include guid
      end
    end

    it 'cannot create a new episode' do
      post :create, episode_hash.to_json, api_version: 'v1', format: 'json', podcast_id: podcast.id
      assert_response :unauthorized
    end

  end
end
