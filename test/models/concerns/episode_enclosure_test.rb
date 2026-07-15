require "test_helper"

class EpisodeEnclosureTest < ActiveSupport::TestCase
  let(:f1) { build_stubbed(:feed, slug: nil, audio_format: nil) }
  let(:f2) { build_stubbed(:feed, slug: "feed-2", enclosure_prefix: "https://the/prefix/") }
  let(:f3) { build_stubbed(:feed, slug: "feed-3", private: true, tokens: [FeedToken.new(token: "tok1"), FeedToken.new(token: "tok2")]) }
  let(:pod) { build_stubbed(:podcast, default_feed: f1, feeds: [f1, f2]) }

  let(:c1) { build_stubbed(:content, position: 1, file_size: 100, original_url: "http://some.where/one.mp3") }
  let(:c2) { build_stubbed(:content, position: 2, file_size: 99, original_url: "http://some.where/two.mp3") }
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
      assert_equal "https://the/prefix/#{dt_host}/#{pod.id}/feed-2/#{ep.guid}/one.flac", ep.enclosure_url(feed: f2)
    end

    it "includes private feed auth" do
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.flac", ep.enclosure_url(feed: f3)
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.flac?auth=tok1", ep.enclosure_url(feed: f3, auth: true)
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.flac?auth=tok2", ep.enclosure_url(feed: f3, auth: "tok2")
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.flac?auth=blah", ep.enclosure_url(feed: f3, auth: "blah")

      # not included for public feeds
      f3.private = false
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.flac", ep.enclosure_url(feed: f3, auth: true)
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.flac", ep.enclosure_url(feed: f3, auth: "tok2")
    end

    it "includes prx jwt auth" do
      assert_equal "https://#{dt_host}/#{pod.id}/#{ep.guid}/one.mp3?_t=my-jwt", ep.enclosure_url(prx_jwt: "my-jwt")
      assert_equal "https://#{dt_host}/#{pod.id}/feed-2/#{ep.guid}/one.flac?_t=my-jwt", ep.enclosure_url(feed: f2, prefix: false, prx_jwt: "my-jwt")
      assert_equal "https://#{dt_host}/#{pod.id}/feed-3/#{ep.guid}/one.flac?_t=my-jwt&auth=tok1", ep.enclosure_url(feed: f3, auth: true, prx_jwt: "my-jwt")
    end
  end

  describe "#enclosure_content_type" do
    it "returns feed content_types" do
      assert_equal "audio/mpeg", ep.enclosure_content_type
      assert_equal "audio/mpeg", ep.enclosure_content_type(feed: f1)
      assert_equal "audio/flac", ep.enclosure_content_type(feed: f2)
      assert_equal "audio/flac", ep.enclosure_content_type(feed: f3)
    end

    it "returns media content_type for overrides and videos" do
      ep.medium = "video"
      c1.mime_type = "video/something"
      assert_equal "video/something", ep.enclosure_content_type

      ep.medium = "override"
      ep.build_external_media_resource(mime_type: "foo/bar")
      assert_equal "foo/bar", ep.enclosure_content_type
    end

    it "forces unsupported mimes to mp3" do
      c1.mime_type = "audio/ogg"
      assert_equal "audio/mpeg", ep.enclosure_content_type
    end
  end

  describe "#enclosure_file_name" do
    it "sets file extensions from the feed" do
      assert_equal "one.mp3", ep.enclosure_file_name
      assert_equal "one.mp3", ep.enclosure_file_name(feed: f1)
      assert_equal "one.flac", ep.enclosure_file_name(feed: f2)
      assert_equal "one.flac", ep.enclosure_file_name(feed: f3)

      c1.original_url = "http://some.where/multiple.segments.here.mp3"
      assert_equal "multiple.segments.here.mp3", ep.enclosure_file_name(feed: f1)
      assert_equal "multiple.segments.here.flac", ep.enclosure_file_name(feed: f2)

      c1.original_url = "http://some.where/no-extension"
      assert_equal "no-extension.mp3", ep.enclosure_file_name(feed: f1)
      assert_equal "no-extension.flac", ep.enclosure_file_name(feed: f2)
    end

    it "returns original filenames of overrides and video" do
      ep.medium = "video"
      c1.original_url = "http://some.where/any.thing.here"
      assert_equal "any.thing.here", ep.enclosure_file_name

      ep.medium = "override"
      assert_equal "", ep.enclosure_file_name

      ep.enclosure_override_url = "http://some.where/override.ogg"
      assert_equal "override.ogg", ep.enclosure_file_name
    end

    it "forces unsupperted extensions to mp3" do
      c1.mime_type = "audio/ogg"
      assert_equal "one.mp3", ep.enclosure_file_name
      assert_equal "one.flac", ep.enclosure_file_name(feed: f2)
    end
  end

  describe "#enclosure_file_size" do
    it "just returns the media file size for now" do
      assert_equal 199, ep.enclosure_file_size
    end

    it "returns override file size" do
      ep.medium = "override"
      ep.build_external_media_resource(file_size: 1234)
      assert_equal 1234, ep.enclosure_file_size
    end
  end
end
