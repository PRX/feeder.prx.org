require 'test_helper'
require 'prx_access'

describe PodcastSeriesHandler do
  include PRXAccess

  let(:podcast) { create(:podcast) }

  let(:profile) { 'https://cms-staging.prx.tech/pub/d754c711890d7b7a57a43a432dd79137/0/web/series_image/15407/original/mothradiohr-whitelogo.jpg' }

  let(:series) do
    msg = json_file(:prx_series)
    body = JSON.parse(msg)
    href = body.dig(:_links, :self, :href)
    resource = PRXAccess::PRXHyperResource.new(root: 'https://cms.prx.org/api/vi/')
    link = PRXAccess::PRXHyperResource::Link.new(resource, href: href)
    PRXAccess::PRXHyperResource.new_from(body: body, resource: resource, link: link)
  end

  before {
    stub_request(:get, profile).
      to_return(status: 200, body: test_file('/fixtures/transistor1400.jpg'), headers: {})
  }

  it 'can be created from a series' do
    podcast = PodcastSeriesHandler.create_from_series!(series)
    refute_nil podcast
    assert_equal podcast.title, 'The Moth Radio Hour'
    assert_match(/^Brought to you by PRX/, podcast.description)
    assert_nil podcast.summary
    assert_match(/^The Moth Radio Hour is a weekly series/, podcast.subtitle)

    assert_equal podcast.itunes_images.first.original_url, profile
    assert_nil podcast.feed_image
  end
end
