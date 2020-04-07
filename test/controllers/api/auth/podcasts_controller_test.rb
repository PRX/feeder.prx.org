require 'test_helper'

describe Api::Auth::PodcastsController do
  let(:account_id) { 123 }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", published_at: nil) }
  let(:published_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: 'pod2') }
  let(:other_account_podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/9876", path: 'pod3') }
  let(:token) { StubToken.new(account_id, ['member']) }

  before do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = token
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  it 'should show the unpublished podcast' do
    podcast.id.wont_be_nil
    podcast.published_at.must_be_nil
    get(:show, { api_version: 'v1', format: 'json', id: podcast.id } )
    assert_response :success
  end

  it 'should not show unowned podcast' do
    get(:show, { api_version: 'v1', format: 'json', id: other_account_podcast.id } )
    assert_response :not_found
  end

  it 'should only index account podcasts' do
    podcast && published_podcast && other_account_podcast
    get(:index, api_version: 'v1')
    assert_response :success
    assert_not_nil assigns[:podcasts]
    assigns[:podcasts].must_include podcast
    assigns[:podcasts].must_include published_podcast
    assigns[:podcasts].wont_include other_account_podcast
  end

  describe 'with wildcard token' do
    let (:token) { StubToken.new('*', ['read-private']) }

    it 'includes all podcasts' do
      podcast && published_podcast && other_account_podcast
      get(:index, api_version: 'v1')
      assert_response :success
      assert_not_nil assigns[:podcasts]
      assigns[:podcasts].must_include podcast
      assigns[:podcasts].must_include published_podcast
      assigns[:podcasts].must_include other_account_podcast
    end
  end
end
