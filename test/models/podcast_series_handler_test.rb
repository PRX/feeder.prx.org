require "test_helper"
require "prx_access"

describe PodcastSeriesHandler do
  include PrxAccess

  let(:podcast) { create(:podcast) }

  let(:profile) { "https://cms-staging.prx.tech/pub/d754c711890d7b7a57a43a432dd79137/0/web/series_image/15407/original/mothradiohr-whitelogo.jpg" }

  let(:series) do
    msg = json_file(:prx_series)
    body = JSON.parse(msg)
    href = body.dig(:_links, :self, :href)
    resource = PrxAccess::PrxHyperResource.new(root: "https://cms.prx.org/api/vi/")
    link = PrxAccess::PrxHyperResource::Link.new(resource, href: href)
    PrxAccess::PrxHyperResource.new_from(body: body, resource: resource, link: link)
  end

  before {
    stub_request(:get, profile)
      .to_return(status: 200, body: test_file("/fixtures/transistor1400.jpg"), headers: {})
  }

  it "can be created from a series" do
    podcast = PodcastSeriesHandler.create_from_series!(series)
    refute_nil podcast
    assert_equal podcast.title, "The Moth Radio Hour"
    assert_match(/^Brought to you by PRX/, podcast.description)
    assert_nil podcast.summary
    assert_match(/^The Moth Radio Hour is a weekly series/, podcast.subtitle)

    # images are unprocessed, so their getters are nil
    assert_nil podcast.default_feed.ready_feed_image
    assert_nil podcast.default_feed.ready_itunes_image

    # but the has_many exists if the image does
    assert_equal 0, podcast.default_feed.feed_images.count
    assert_equal 1, podcast.default_feed.itunes_images.count
    assert_equal podcast.default_feed.itunes_images.first, podcast.default_feed.itunes_image

    # should also parse caption/credit
    assert_equal "created", podcast.default_feed.itunes_image.status
    assert_equal "mothradiohr-whitelogo.jpg", podcast.default_feed.itunes_image.file_name
    assert_equal profile, podcast.default_feed.itunes_image.original_url
    assert_equal "jpeg", podcast.default_feed.itunes_image.format
    assert_equal 36, podcast.default_feed.itunes_image.guid.length
    assert_equal 1400, podcast.default_feed.itunes_image.height
    assert_equal 1400, podcast.default_feed.itunes_image.width
    assert_equal "this-caption", podcast.default_feed.itunes_image.caption
    assert_equal "this-credit", podcast.default_feed.itunes_image.credit
  end
end
