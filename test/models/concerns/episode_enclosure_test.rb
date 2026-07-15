require "test_helper"

class EpisodeEnclosureTest < ActiveSupport::TestCase
  let(:f1) { build_stubbed(:feed, slug: nil) }
  let(:f2) { build_stubbed(:feed, slug: "feed-2", enclosure_prefix: "https://the/prefix/") }
  let(:f3) { build_stubbed(:feed, slug: "feed-3", private: true, tokens: [FeedToken.new(token: "tok1"), FeedToken.new(token: "tok2")]) }
  let(:pod) { build_stubbed(:podcast, default_feed: f1, feeds: [f1, f2]) }

  let(:c1) { build_stubbed(:content, position: 1, original_url: "http://some.where/one.mp3") }
  let(:c2) { build_stubbed(:content, position: 2, original_url: "http://some.where/two.mp3") }
  let(:ep) { build_stubbed(:episode, segment_count: 2, podcast: pod, contents: [c1, c2]) }

  let(:dt_host) { ENV["DOVETAIL_HOST"] }

  describe "#enclosure_url" do
    it "builds enclosure urls" do
      assert_equal "https://#{dt_host}/#{pod.id}/#{ep.guid}/one.mp3", ep.enclosure_url
    end

    it "optionally includes prefixes" do
      f1.enclosure_prefix = "http://pre-1"
      assert_equal "http://pre-1/#{dt_host}/#{pod.id}/#{ep.guid}/one.mp3", ep.enclosure_url

      # handles trailing slashes
      f1.enclosure_prefix = "https://pre-1/"
      assert_equal "https://pre-1/#{dt_host}/#{pod.id}/#{ep.guid}/one.mp3", ep.enclosure_url

      # can be omitted
      assert_equal "https://#{dt_host}/#{pod.id}/#{ep.guid}/one.mp3", ep.enclosure_url(prefix: false)
    end

    it "includes custom feed slugs" do
      assert_equal "https://#{dt_host}/#{pod.id}/#{ep.guid}/one.mp3", ep.enclosure_url(feed: f1)
      assert_equal "https://the/prefix/#{dt_host}/#{pod.id}/feed-2/#{ep.guid}/one.mp3", ep.enclosure_url(feed: f2)
    end

    it "includes private feed auth" do
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.mp3", ep.enclosure_url(feed: f3)
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.mp3?auth=tok1", ep.enclosure_url(feed: f3, auth: true)
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.mp3?auth=tok2", ep.enclosure_url(feed: f3, auth: "tok2")
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.mp3?auth=blah", ep.enclosure_url(feed: f3, auth: "blah")

      # not included for public feeds
      f3.private = false
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.mp3", ep.enclosure_url(feed: f3, auth: true)
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.mp3", ep.enclosure_url(feed: f3, auth: "tok2")
    end

    it "includes prx jwt auth" do
      assert_equal "https://#{dt_host}/#{pod.id}/#{ep.guid}/one.mp3?_t=my-jwt", ep.enclosure_url(prx_jwt: "my-jwt")
      assert_equal "https://#{dt_host}/#{pod.id}/feed-2/#{ep.guid}/one.mp3?_t=my-jwt", ep.enclosure_url(feed: f2, prefix: false, prx_jwt: "my-jwt")
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.mp3?_t=my-jwt&auth=tok1", ep.enclosure_url(feed: f3, auth: true, prx_jwt: "my-jwt")
    end
  end
end
