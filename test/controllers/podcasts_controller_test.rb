require 'test_helper'

describe PodcastsController do
  before do
    stub_requests_to_prx_cms
    @podcast = create(:podcast, updated_at: Time.now)
  end

  it 'redirects to the published url if the podcast is locked' do
    @podcast.update_attribute(:locked, true)
    get :show, id: @podcast.id, format: 'rss'

    assert_equal response.headers['Location'], 'https://f.prxu.org/jjgo/feed-rss.xml'
    assert_equal response.status.to_i, 302
  end

  it 'does not redirect if the podcast is locked but param unlock' do
    @podcast.update_attribute(:locked, true)
    get :show, id: @podcast.id, format: 'rss', unlock: true

    assert_equal response.status.to_i, 200
  end

  it 'returns a fresh version of the podcast when it has been updated' do
    @request.headers["HTTP_IF_MODIFIED_SINCE"] = 1.day.ago.strftime('%a, %d %b %Y %H:%M:%S %Z')
    get :show, id: @podcast.id, format: 'rss'

    assert_equal response.status.to_i, 200
  end

  it 'returns 304 if the resource has not been updated' do
    @request.headers["HTTP_IF_MODIFIED_SINCE"] = Time.now.strftime('%a, %d %b %Y %H:%M:%S %Z')
    get :show, id: @podcast.id, format: 'rss'

    assert_equal response.status.to_i, 304
  end

  it 'rss includes itunes block yes when podcast itunes_block true' do
    get :show, id: @podcast.id, format: 'rss'
    refute_match(/itunes:block/, response.body)

    @podcast.update_attribute(:itunes_block, true)
    get :show, id: @podcast.id, format: 'rss'
    assert_match(/itunes:block>Yes/, response.body)
  end
end
