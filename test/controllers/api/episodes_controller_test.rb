require 'test_helper'

describe Api::EpisodesController do
  let(:episode) { create(:episode) }
  let(:podcast) { episode.podcast }
  let(:episode_deleted) { create(:episode, deleted_at: Time.now, podcast: podcast) }
  let(:episode_unpublished) { create(:episode, published_at: nil, podcast: podcast) }
  let(:episode_prepublished) { create(:episode, published_at: (Time.now + 1.week), podcast: podcast) }

  let(:episode_hash) do
    {
      prxUri: '/api/v1/stories/123',
      media: [
        { href: 'https://s3.amazonaws.com/prx-testing/test/audio1.mp3' },
        { href: 'https://s3.amazonaws.com/prx-testing/test/audio2.mp3' },
        { href: 'https://s3.amazonaws.com/prx-testing/test/audio3.mp3' }
      ]
    }
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

  it 'should return resource unknown for unpublished resource' do
    episode_unpublished.id.wont_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: episode_unpublished.guid } )
    assert_response 404
  end

  it 'should return not found for unknown resource' do
    episode_deleted.id.wont_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: 'thisismadeup' } )
    assert_response 404
  end

  it 'should list' do
    episode.id.wont_be_nil
    episode_deleted.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
    guids = JSON.parse(response.body)['_embedded']['prx:items'].map { |p| p['id'] }
    guids.must_include(episode.guid)
    guids.wont_include(episode_deleted.guid)
  end

  it 'should not list future published' do
    episode_unpublished.id.wont_be_nil
    episode_prepublished.id.wont_be_nil
    episode.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
    list = JSON.parse(response.body)
    ids = list.dig('_embedded', 'prx:items').map{ |i| i['id'] }
    ids.must_include(episode.guid)
    ids.wont_include(episode_prepublished.guid)
    ids.wont_include(episode_unpublished.guid)
  end

  it 'should list for podcast' do
    episode.id.wont_be_nil
    episode_deleted.id.wont_be_nil
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json', podcast_id: podcast.id } )
    assert_response :success
    guids = JSON.parse(response.body)['_embedded']['prx:items'].map { |p| p['id'] }
    guids.must_include(episode.guid)
    guids.wont_include(episode_deleted.guid)
  end

  describe 'with a valid token' do
    let(:account_id) { 123 }
    let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
    let(:episode_redirect) { create(:episode, podcast: podcast, published_at: nil) }
    let(:episode_update) { create(:episode, podcast: podcast, published_at: nil) }
    let(:token) { StubToken.new(account_id, ['member']) }

    around do |test|
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env['CONTENT_TYPE'] = 'application/json'
      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) { test.call }
      end
    end


    it 'should redirect for authorized request of unpublished resource' do
      episode_redirect.id.wont_be_nil
      get(:show, { api_version: 'v1', format: 'json', id: episode_redirect.guid } )
      assert_response :redirect
    end

    it 'can create a new episode' do
      post :create, episode_hash.to_json, api_version: 'v1', format: 'json', podcast_id: podcast.id
      assert_response :success
      id = JSON.parse(response.body)['id']
      new_episode = Episode.find_by_guid(id)
      new_episode.prx_uri.must_equal '/api/v1/stories/123'
      new_episode.enclosures.count.must_equal 0
      new_episode.all_contents.count.must_equal 3
      c = new_episode.all_contents.first
      c.original_url.must_equal 'https://s3.amazonaws.com/prx-testing/test/audio1.mp3'
    end

    it 'can update on create of a new episode' do
      ep = create(:episode, published_at: (Time.now + 1.week), podcast: podcast, prx_uri: '/api/v1/stories/123')
      post :create, episode_hash.to_json, api_version: 'v1', format: 'json', podcast_id: podcast.id
      assert_response :success
      id = JSON.parse(response.body)['id']
      new_episode = Episode.find_by_guid(id)
      ep.id.must_equal new_episode.id

      new_episode.all_contents.count.must_equal 3
      c = new_episode.all_contents.first
      c.original_url.must_equal 'https://s3.amazonaws.com/prx-testing/test/audio1.mp3'
    end

    it 'can update audio on an episode' do
      update_hash = {
        media: [{
          href: 'https://s3.amazonaws.com/prx-testing/test/change1.mp3',
          type: 'audio/mpeg',
          size: 123456,
          duration: '1234.5678',
        }]
      }

      episode_update.all_contents.size.must_equal 0

      put :update, update_hash.to_json, id: episode_update.guid, api_version: 'v1', format: 'json'
      assert_response :success

      contents = episode_update.reload.all_contents
      contents.size.must_equal 1
      contents.first.mime_type.must_equal 'audio/mpeg'
      contents.first.file_size.must_equal 123456
      contents.first.duration.to_s.must_equal '1234.5678'
      guid1 = contents.first.guid

      # updating with a dupe should insert it
      update_hash = { media: [{ href: update_hash[:media][0][:href] }] }
      put :update, update_hash.to_json, id: episode_update.guid, api_version: 'v1', format: 'json'
      assert_response :success

      contents = episode_update.reload.all_contents
      contents.size.must_equal 2

      contents.first.guid.wont_equal guid1
      contents.first.position.must_equal 1
      contents.first.mime_type.must_be_nil
      contents.first.file_size.must_be_nil
      contents.first.duration.must_be_nil

      contents.last.guid.must_equal guid1
      contents.last.position.must_equal 1
      contents.last.mime_type.must_equal 'audio/mpeg'
      contents.last.file_size.must_equal 123456
      contents.last.duration.to_s.must_equal '1234.5678'

      # updating without media does nothing
      update_hash = { title: 'a new title' }
      put :update, update_hash.to_json, id: episode_update.guid, api_version: 'v1', format: 'json'
      assert_response :success
      episode_update.reload.all_contents.size.must_equal 2

      # updating with an empty array deletes
      update_hash = { media: [] }
      put :update, update_hash.to_json, id: episode_update.guid, api_version: 'v1', format: 'json'
      assert_response :success
      episode_update.reload.all_contents.size.must_equal 0
    end
  end
end
