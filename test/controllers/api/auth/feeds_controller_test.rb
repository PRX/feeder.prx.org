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
    around do |test|
      class << @controller; attr_accessor :prx_auth_token; end
      @controller.prx_auth_token = token
      @request.env['CONTENT_TYPE'] = 'application/json'
      @controller.stub(:publish, true) do
        test.call
      end
    end

    it 'can create a new feed' do
      post(:create, body: feed_hash.to_json, as: :json,
                    params: { api_version: 'v1', format: 'json', podcast_id: podcast.id })
      assert_response :success
      id = JSON.parse(response.body)['id']
      new_feed = Feed.find(id)
      _(new_feed.slug).must_equal 'test-slug'
    end

    it 'can update a feed' do
      fua = feed.updated_at
      update_hash = { title: 'new title', slug: 'somesluggy1' }

      put(:update, body: update_hash.to_json, as: :json,
                   params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })
      assert_response :success

      _(feed.reload.updated_at).must_be :>, fua
      _(feed.title).must_equal 'new title'
    end

    describe 'feed tokens' do
      before do
        feed.tokens.create!(label: 'something', token: 'tok1')
        feed.tokens.create!(token: 'tok2')
      end

      it 'can create a new feed with tokens' do
        token_hash = {
          slug: 'token-slug',
          tokens: [
            { token: 'tok3', label: 'tok3', expires: '2023-02-01' },
            { token: 'tok4' }
          ]
        }

        post(:create, body: token_hash.to_json, as: :json,
                      params: { api_version: 'v1', format: 'json', podcast_id: podcast.id })

        assert_response :success
        id = JSON.parse(response.body)['id']
        new_feed = Feed.find(id)
        _(new_feed.reload.tokens.count).must_equal 2
      end

      it 'can update nested tokens' do
        update_tok1 = { token: 'tok1', label: 'else', expires: '2023-02-01' }
        create_tok3 = { token: 'tok3' }
        update_hash = { tokens: [update_tok1, create_tok3] }

        put(:update, body: update_hash.to_json, as: :json,
                     params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })

        assert_response :success
        _(feed.reload.tokens.count).must_equal 2
      end

      it 'can delete nested tokens' do
        update_hash = { tokens: [] }

        put(:update, body: update_hash.to_json, as: :json,
                     params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })

        assert_response :success
        _(feed.reload.tokens.count).must_equal 0
      end
    end

    describe 'feed images' do
      let(:file) { test_file('/fixtures/transistor1400.jpg') }
      let(:url1) { 'http://www.prx.org/fakeimageurl1.jpg' }
      let(:url2) { 'http://www.prx.org/fakeimageurl2.jpg' }
      before { stub_request(:get, url1).to_return(status: 200, body: file, headers: {}) }
      before { stub_request(:get, url2).to_return(status: 200, body: file, headers: {}) }

      it 'appends feed and itunes images' do
        _(feed.feed_images.count).must_equal 0
        fua = feed.updated_at

        update_hash = { feedImage: { href: url1, caption: 'd1' } }
        put(:update, body: update_hash.to_json, as: :json,
                     params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })
        assert_response :success

        _(feed.reload.updated_at).must_be :>, fua
        _(feed.feed_images.count).must_equal 1
        _(feed.feed_images.first.caption).must_equal 'd1'
        _(feed.itunes_images.count).must_equal 0
        fua = feed.updated_at

        update_hash = { feedImage: { href: url2, caption: 'd2' }, itunesImage: { href: url1, caption: 'd3' } }
        put(:update, body: update_hash.to_json, as: :json,
                     params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })
        assert_response :success
        put(:update, body: update_hash.to_json, as: :json,
                     params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })
        assert_response :success

        _(feed.reload.updated_at).must_be :>, fua
        _(feed.feed_images.count).must_equal 2
        _(feed.feed_images.first.caption).must_equal 'd2'
        _(feed.feed_images.last.caption).must_equal 'd1'
        _(feed.itunes_images.count).must_equal 1
        _(feed.itunes_images.last.caption).must_equal 'd3'
      end
    end

    it 'ignores updating invalid overrides' do
      fua = feed.updated_at
      update_hash = { title: 'new title2', slug: 'somesluggy2', display_episodes_count: 1 }

      put(:update, body: update_hash.to_json, as: :json,
                   params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })
      assert_response :success

      feed.reload
      _(feed.updated_at).must_be :>, fua
      _(feed.slug).must_equal 'somesluggy2'
    end

    it 'rejects update for unauthorizd token' do
      @controller.prx_auth_token = bad_token
      update_hash = { title: 'new title3', slug: 'somesluggy3', display_episodes_count: 1 }

      put(:update, body: update_hash.to_json, as: :json,
                   params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })
      assert_response 401
    end
  end

  it 'should show' do
    get(:show, params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id, id: feed.id })
    assert_response :success
  end

  it 'should list' do
    _(feed.id).wont_be_nil
    get(:index, params: { api_version: 'v1', format: 'json', podcast_id: feed.podcast_id })
    assert_response :success
    ids = JSON.parse(response.body)['_embedded']['prx:items'].map { |p| p['id'] }
    _(ids).must_include(feed.id)
  end
end
