require 'test_helper'

describe Api::PodcastsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:token) { StubToken.new(account_id, ['member']) }
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

    it 'can create a new podcast' do
      post :create, podcast_hash.to_json, api_version: 'v1', format: 'json'
      assert_response :success
      id = JSON.parse(response.body)['id']
      new_podcast = Podcast.find(id)
      new_podcast.itunes_categories.first.name.must_equal 'Arts'
    end

    it 'can update a podcast' do
      pua = podcast.updated_at
      podcast.itunes_categories.size.must_be :>, 0
      update_hash = { itunesCategories: [] }

      put :update, update_hash.to_json, id: podcast.id, api_version: 'v1', format: 'json'
      assert_response :success

      podcast.reload.updated_at.must_be :>, pua
      podcast.itunes_categories.size.must_equal 0
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

  it 'should list' do
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
  end
end
