require 'test_helper'

describe Api::Auth::FeedsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:feed) { create(:feed, podcast: podcast, slug: 'test-slug') }
  let(:token) { StubToken.new(account_id, ['member']) }
  let(:bad_token) { StubToken.new(account_id + 100, ['member']) }

  let(:feed_hash) do
    {
      slug: 'test-slug'
    }
  end

  describe 'with a valid token' do
    before do
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env['CONTENT_TYPE'] = 'application/json'
    end

    it 'can create a new feed' do
      post :create, feed_hash.to_json, api_version: 'v1', format: 'json', podcast_id: podcast.id
      assert_response :success
      id = JSON.parse(response.body)['id']
      new_feed = Feed.find(id)
      _(new_feed.slug).must_equal 'test-slug'
    end

    it 'can update a feed' do
      fua = feed.updated_at
      update_hash = { title: 'new title', slug: 'somesluggy1' }

      put :update, update_hash.to_json, api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id
      assert_response :success

      _(feed.reload.updated_at).must_be :>, fua
      _(feed.title).must_equal 'new title'
    end

    it 'ignores updating invalid overrides' do
      fua = feed.updated_at
      update_hash = { title: 'new title2', slug: 'somesluggy2', display_episodes_count: 1 }

      put :update, update_hash.to_json, api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id
      assert_response :success

      feed.reload
      _(feed.updated_at).must_be :>, fua
      _(feed.slug).must_equal 'somesluggy2'
    end

    it 'rejects update for unauthorizd token' do
      @controller.prx_auth_token = bad_token
      update_hash = { title: 'new title3', slug: 'somesluggy3', display_episodes_count: 1 }

      put :update, update_hash.to_json, api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id
      assert_response 401
    end
  end

  it 'should show' do
    get(:show, { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id } )
    assert_response :success
  end

  it 'should list' do
    _(feed.id).wont_be_nil
    get(:index, { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id } )
    assert_response :success
    ids = JSON.parse(response.body)['_embedded']['prx:items'].map { |p| p['id'] }
    _(ids).must_include(feed.id)
  end
end
