require 'test_helper'

describe Api::PodcastsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:podcast_deleted) { create(:podcast, path: 'deleted', deleted_at: Time.now) }
  let(:podcast_redirect) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", published_at: nil) }
  let(:token) { StubToken.new(account_id, ['member']) }
  let(:bad_token) { StubToken.new(account_id + 100, ['member']) }

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
      @controller.prx_auth_token = token
      @request.env['CONTENT_TYPE'] = 'application/json'
    end

    it 'should redirect for authorized request of unpublished resource' do
      podcast_redirect.id.wont_be_nil
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
      new_podcast.itunes_categories.first.name.must_equal 'Arts'
    end

    it 'can update a podcast' do
      pua = podcast.updated_at
      podcast.itunes_categories.size.must_be :>, 0
      update_hash = { itunesCategories: [] }

      @controller.stub(:publish, true) do
        @controller.stub(:process_media, true) do
          put :update, update_hash.to_json, id: podcast.id, api_version: 'v1', format: 'json'
        end
      end
      assert_response :success

      podcast.reload.updated_at.must_be :>, pua
      podcast.itunes_categories.size.must_equal 0
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
      podcast.reload.updated_at.must_be :>, pua
      res = JSON.parse(response.body)
      res['published_url'].wont_equal 'this is read only'
      res['title'].must_equal 'new title'
    end

    it 'rejects update for unauthorizd token' do
      @controller.prx_auth_token = bad_token
      pua = podcast.updated_at
      podcast.itunes_categories.size.must_be :>, 0
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
    podcast_deleted.id.wont_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: podcast_deleted.id } )
    assert_response 410
  end

  it 'should list' do
    podcast_deleted.id.wont_be_nil
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
    ids = JSON.parse(response.body)['_embedded']['prx:items'].map { |p| p['id'] }
    ids.wont_include(podcast_deleted.id)
  end

  it 'should list podcasts for an account' do
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json', prx_account_uri: "/api/v1/accounts/#{account_id}" } )
    assert_response :success
    podcasts = JSON.parse(response.body)['_embedded']['prx:items']
    podcasts.count.must_equal 1
  end

  it 'should not list podcasts for a different account' do
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json', prx_account_uri: "/api/v1/accounts/#{account_id}99" } )
    assert_response :success
    podcasts = JSON.parse(response.body)['_embedded']['prx:items']
    podcasts.count.must_equal 0
  end
end
