require 'test_helper'

describe PodcastsController do
  before do
    stub_requests_to_prx_cms
    @podcast = create(:podcast, updated_at: Time.now)
  end

  it 'redirects to the published url if the podcast is locked' do
    @podcast.update_attribute(:locked, true)
    get :show, id: @podcast.id, format: 'rss'

    response.headers['Location'].must_equal 'https://f.prxu.org/jjgo/feed-rss.xml'
    response.status.to_i.must_equal 302
  end

  it 'does not redirect if the podcast is locked but param unlock' do
    @podcast.update_attribute(:locked, true)
    get :show, id: @podcast.id, format: 'rss', unlock: true

    response.status.to_i.must_equal 200
  end

  it 'returns a fresh version of the podcast when it has been updated' do
    @request.headers["HTTP_IF_MODIFIED_SINCE"] = 1.day.ago.strftime('%a, %d %b %Y %H:%M:%S %Z')
    get :show, id: @podcast.id, format: 'rss'

    response.status.to_i.must_equal 200
  end

  it 'returns 304 if the resource has not been updated' do
    @request.headers["HTTP_IF_MODIFIED_SINCE"] = Time.now.strftime('%a, %d %b %Y %H:%M:%S %Z')
    get :show, id: @podcast.id, format: 'rss'

    response.status.to_i.must_equal 304
  end
end
