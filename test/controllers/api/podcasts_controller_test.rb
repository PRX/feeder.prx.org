require 'test_helper'

describe Api::PodcastsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:podcast_deleted) { create(:podcast, path: 'deleted', deleted_at: Time.now) }
  let(:podcast_redirect) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", published_at: nil) }
  let(:member_token) { StubToken.new(account_id, ['member feeder:read-private feeder:podcast-edit feeder:podcast-create']) }
  let(:limited_token) { StubToken.new(account_id + 100, ['member feeder:episode']) }
  let(:admin_token) { StubToken.new(account_id, ['admin feeder:read-private feeder:podcast-edit feeder:podcast-create feeder:podcast-delete']) }

  let(:podcast_hash) do
    {
      path: 'testcast',
      prxUri: '/api/v1/series/123',
      prxAccountUri: "/api/v1/accounts/#{account_id}",
      itunesCategories: [{ name: 'Arts', subcategories: ['Design', 'Fashion & Beauty'] }]
    }
  end

  describe 'with a valid token' do
    before do
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = member_token
      @request.env['CONTENT_TYPE'] = 'application/json'
    end

    it 'should redirect for authorized request of unpublished resource' do
      refute_nil podcast_redirect.id
      get(:show, { api_version: 'v1', format: 'json', id: podcast_redirect.id } )
      assert_response :redirect
    end

    it 'can create a new podcast' do
      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          post :create, podcast_hash.to_json, api_version: 'v1', format: 'json'
        end
      end
      assert_response :success
      id = JSON.parse(response.body)['id']
      new_podcast = Podcast.find(id)
      assert_equal new_podcast.itunes_categories.first.name, 'Arts'
    end

    it 'can update a podcast' do
      pua = podcast.updated_at
      assert_operator podcast.itunes_categories.size, :>, 0
      update_hash = { itunesCategories: [] }

      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          put :update, update_hash.to_json, id: podcast.id, api_version: 'v1', format: 'json'
        end
      end
      assert_response :success

      assert_operator podcast.reload.updated_at, :>, pua
      assert_equal podcast.itunes_categories.size, 0
    end

    it 'cannot delete a podcast with a member token' do
      delete :destroy, id: podcast.id, api_version: 'v1', format: 'json'
      assert_response :unauthorized
    end

    it 'can delete a podcast with an admin token' do
      @controller.prx_auth_token = admin_token
      delete :destroy, id: podcast.id, api_version: 'v1', format: 'json'
      assert_response :no_content
    end

    it 'returns errors for any errors' do
      # create a podcast with a specific path so it will cause dupe path error
      create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: 'dupe')
      update_hash = { path: 'dupe' }
      @controller.stub(:publish, true) do
        put :update, update_hash.to_json, id: podcast.id, api_version: 'v1', format: 'json'
      end
      assert_response :error
    end

    it 'ignores updating readonly attribute' do
      pua = podcast.updated_at
      update_hash = { published_url: 'this is read only', title: 'new title' }

      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          put :update, update_hash.to_json, id: podcast.id, api_version: 'v1', format: 'json'
        end
      end
      assert_response :success
      assert_operator podcast.reload.updated_at, :>, pua
      res = JSON.parse(response.body)
      refute_equal res['published_url'], 'this is read only'
      assert_equal res['title'], 'new title'
    end

    it 'rejects update for unauthorizd token' do
      @controller.prx_auth_token = limited_token
      pua = podcast.updated_at
      assert_operator podcast.itunes_categories.size, :>, 0
      update_hash = { itunesCategories: [] }

      @controller.stub(:publish, true) do
        put :update, update_hash.to_json, id: podcast.id, api_version: 'v1', format: 'json'
      end
      assert_response 401
    end

    it 'rejects create without valid token' do
      @controller.prx_auth_token = nil
      post :create, podcast_hash.to_json, api_version: 'v1', format: 'json'
      assert_response 401
    end
  end

  it 'should show' do
    get(:show, { api_version: 'v1', format: 'json', id: podcast.id } )
    assert_response :success
  end

  it 'should return resource gone for deleted resource' do
    refute_nil podcast_deleted.id
    get(:show, { api_version: 'v1', format: 'json', id: podcast_deleted.id } )
    assert_response 410
  end

  it 'should list' do
    refute_nil podcast_deleted.id
    refute_nil podcast.id
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
    ids = JSON.parse(response.body)['_embedded']['prx:items'].map { |p| p['id'] }
    refute_includes ids, podcast_deleted.id
  end

  it 'should list podcasts for an account' do
    refute_nil podcast.id
    get(:index, { api_version: 'v1', format: 'json', prx_account_uri: "/api/v1/accounts/#{account_id}" } )
    assert_response :success
    podcasts = JSON.parse(response.body)['_embedded']['prx:items']
    assert_equal podcasts.count, 1
  end

  it 'should not list podcasts for a different account' do
    refute_nil podcast.id
    get(:index, { api_version: 'v1', format: 'json', prx_account_uri: "/api/v1/accounts/#{account_id}99" } )
    assert_response :success
    podcasts = JSON.parse(response.body)['_embedded']['prx:items']
    assert_equal podcasts.count, 0
  end
end
