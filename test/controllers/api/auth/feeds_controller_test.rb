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

  #   it 'can update a feed' do
  #     fua = feed.updated_at
  #     feed.overrides.keys.size.must_equal 0
  #     update_hash = { overrides: { title: 'new title', display_episodes_count: 1 } }

  #     put :update, update_hash.to_json, api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id
  #     assert_response :success

  #     feed.reload.updated_at.must_be :>, fua
  #     feed.overrides.keys.size.must_equal 2
  #   end

  #   it 'ignores updating invalid overrides' do
  #     fua = feed.updated_at
  #     feed.overrides.keys.size.must_equal 0
  #     update_hash = { overrides: { title: 'new title', nope: 'nada' } }

  #     put :update, update_hash.to_json, api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id
  #     assert_response :success

  #     feed.reload.updated_at.must_be :>, fua
  #     feed.overrides.keys.size.must_equal 1
  #   end

  #   it 'rejects update for unauthorizd token' do
  #     @controller.prx_auth_token = bad_token
  #     feed.overrides.keys.size.must_equal 0
  #     update_hash = { overrides: { title: 'new title', display_episodes_count: 1 } }

  #     put :update, update_hash.to_json, api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id
  #     assert_response 401
  #   end
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