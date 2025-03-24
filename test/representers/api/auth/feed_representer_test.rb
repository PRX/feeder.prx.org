require "test_helper"

describe Api::Auth::FeedRepresenter do
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast) }
  let(:megaphone_feed) { create(:megaphone_feed, podcast: podcast) }
  let(:representer) { Api::Auth::FeedRepresenter.new(feed) }
  let(:json) { JSON.parse(representer.to_json) }

  it "includes basic properties" do
    _(json["slug"]).must_match(/myfeed(\d+)/)
    _(json["subtitle"]).must_equal feed.subtitle
    _(json["description"]).must_equal feed.description
  end

  it "has links" do
    _(json["_links"]["self"]["href"]).must_equal "/api/v1/authorization/podcasts/#{feed.podcast.id}/feeds/#{feed.id}"
    _(json["_links"]["prx:podcast"]["href"]).must_equal "/api/v1/authorization/podcasts/#{feed.podcast.id}"
  end

  it "has a feed rss link" do
    _(json["_links"]["prx:private-feed"]["href"]).must_equal feed.published_url.to_s
    _(json["_links"]["prx:private-feed"]["templated"]).must_equal true
    _(json["_links"]["prx:private-feed"]["type"]).must_equal "application/rss+xml"
  end

  it "has feed and itunes images" do
    create(:feed_image, feed: feed, alt_text: "d1")
    create(:itunes_image, feed: feed, alt_text: "d2", created_at: 1.minute.ago)
    create(:itunes_image, feed: feed, alt_text: "d3", status: "error")

    # API should always return the latest image of any status
    _(json["feedImage"]["altText"]).must_equal "d1"
    _(json["itunesImage"]["altText"]).must_equal "d3"
  end

  it "allows draft audio for megaphone feeds only" do
    _(json["serveDrafts"]).must_equal false

    mp_json = JSON.parse(Api::Auth::FeedRepresenter.new(megaphone_feed).to_json)
    _(mp_json["serveDrafts"]).must_equal true
  end
end
