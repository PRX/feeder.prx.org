require "test_helper"
require "enclosure_url_builder"

describe EnclosureUrlBuilder do
  let(:template) { "https://#{ENV["DOVETAIL_HOST"]}/{slug}/{guid}/{original_filename}" }
  let(:prefix) { "http://www.podtrac.com/pts/redirect.mp3/media.blubrry.com/jojego/" }
  let(:podcast) { create(:podcast, enclosure_prefix: prefix, enclosure_template: template) }
  let(:episode) { create(:episode_with_media, podcast: podcast) }
  let(:feed) { create(:feed, podcast: podcast, slug: "no-ads-pls") }
  let(:builder) { EnclosureUrlBuilder.new }

  before(:each) {
    podcast.enclosure_prefix = prefix
    podcast.enclosure_template = template
  }

  it "can make a base enclosure url with template and expansions" do
    template = "https://test.prx.tech/{a}/{b}{c}"
    expansions = {a: "path", b: "file", c: ".mp3"}

    url = builder.enclosure_url(template, expansions)
    _(url).must_equal "https://test.prx.tech/path/file.mp3"
  end

  it "can add a prefix to a base enclosure url" do
    base_enclosure_url = "https://test.prx.tech/path/file.mp3"
    prefix = "https://prefix.prx.tech/pre"
    url = builder.enclosure_prefix_url(base_enclosure_url, prefix)

    _(url).must_equal "https://prefix.prx.tech/pre/test.prx.tech/path/file.mp3"
  end

  it "can make expansions for a podcast and episode" do
    expansions = builder.podcast_episode_expansions(podcast, episode, feed)
    _(expansions[:original_filename]).must_equal "audio.mp3"
    _(expansions[:original_extension]).must_equal ".mp3"
    _(expansions[:original_basename]).must_equal "audio"
    _(expansions[:filename]).must_match(/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/)
    _(expansions[:extension]).must_equal ".mp3"
    _(expansions[:basename]).must_match(/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+)/)
    _(expansions[:slug]).must_equal podcast.id
    _(expansions[:feed_slug]).must_equal "no-ads-pls"
    _(expansions[:feed_extension]).must_equal ".flac"
    _(expansions[:guid]).must_match(/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)/)
    _(expansions[:original_scheme]).must_equal "s3"
    _(expansions[:original_host]).must_equal "prx-testing"
    _(expansions[:original_path]).must_equal "/test/audio.mp3"
    _(expansions[:scheme]).must_equal "https"
    _(expansions[:host]).must_equal "f.prxu.org"
    _(expansions[:path]).must_match(/\/#{podcast.path}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/)
  end

  describe "uncut filenames" do
    it "prefers the uncut filename over contents" do
      exp = builder.podcast_episode_expansions(podcast, episode, feed)
      assert_equal "audio.mp3", exp[:original_filename]

      episode.build_uncut(original_url: "http://some.where/uncut.flac")

      exp = builder.podcast_episode_expansions(podcast, episode, feed)
      assert_equal "uncut.flac", exp[:original_filename]
      assert_equal "uncut", exp[:original_basename]
      assert_equal ".flac", exp[:original_extension]
    end

    it "has a default, just in case there is no undeleted media" do
      ep_no_media = build_stubbed(:episode, podcast: podcast)
      assert_empty ep_no_media.contents
      assert_nil ep_no_media.uncut

      # published eps should always have media in _some_ status, but just in case
      exp = builder.podcast_episode_expansions(podcast, ep_no_media, feed)
      assert_equal "media", exp[:original_filename]
      assert_equal "media", exp[:original_basename]
      assert_equal "", exp[:original_extension]
    end
  end

  describe "default feed extensions when audio format is not present" do
    before do
      feed.audio_format[:f] = nil
    end

    it "keeps extensions if wav or flac" do
      episode.contents.first.original_url.sub!(/mp3/, "wav")
      expansions = builder.podcast_episode_expansions(podcast, episode, feed)
      _(expansions[:extension]).must_equal ".wav"
    end

    it "defaults extensions to .mp3 if not wav or flac" do
      episode.contents.first.original_url.sub!(/mp3/, "ogg")
      expansions = builder.podcast_episode_expansions(podcast, episode, feed)
      _(expansions[:extension]).must_equal ".mp3"
    end

    it "keeps extensions if medium is video" do
      episode.contents.first.original_url.sub!(/mp3/, "mp4")
      episode.contents.first.medium = "video"
      expansions = builder.podcast_episode_expansions(podcast, episode, feed)
      _(expansions[:extension]).must_equal ".mp4"
    end
  end

  it "can make an enclosure url for a podcast and episode with template" do
    podcast.enclosure_prefix = nil
    url = builder.podcast_episode_url(podcast, episode)
    _(url).must_match(/https:\/\/dovetail.prxu.org\/#{podcast.id}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/audio.mp3/)
  end

  it "can make an enclosure url for a podcast and episode with prefix" do
    podcast.enclosure_template = nil
    url = builder.podcast_episode_url(podcast, episode)
    _(url).must_match(/http:\/\/www.podtrac.com\/pts\/redirect.mp3\/media.blubrry.com\/jojego\/dovetail.prxu.org\/#{podcast.id}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/audio\.mp3/)
  end

  it "can make an enclosure url for a podcast and episode with template and prefix" do
    url = builder.podcast_episode_url(podcast, episode)
    _(url).must_match(/http:\/\/www.podtrac.com\/pts\/redirect.mp3\/media.blubrry.com\/jojego\/dovetail.prxu.org\/#{podcast.id}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/audio\.mp3/)
  end

  it "can make an enclosure url for an override url, but not override prefix" do
    episode.enclosure_override_url = "https://a.io/a.mp3"
    episode.enclosure_override_prefix = false

    url = builder.podcast_episode_url(podcast, episode)
    _(url).must_equal("http://www.podtrac.com/pts/redirect.mp3/media.blubrry.com/jojego/a.io/a.mp3")
  end
  it "can make an enclosure url for an override url, also override prefix" do
    episode.enclosure_override_url = "https://a.io/a.mp3"
    episode.enclosure_override_prefix = true

    url = builder.podcast_episode_url(podcast, episode)
    _(url).must_equal("https://a.io/a.mp3")
  end

  it "applies template to audio file link" do
    podcast.enclosure_prefix = nil
    podcast.enclosure_template = "http://foo.com/r{extension}/b/n/{host}{+path}"
    url = builder.podcast_episode_url(podcast, episode)
    _(url).must_match(/http:\/\/foo\.com\/r\.mp3\/b\/n\/f\.prxu\.org\/#{podcast.path}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+)\.mp3/)
  end

  it "can make an enclosure url for a specific feed" do
    url = builder.podcast_episode_url(podcast, episode, feed)
    _(url).must_match(/#{podcast.id}\/no-ads-pls\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/audio\.flac/)
  end

  describe "a set of class methods to mark (annotate) enclosure urls" do
    describe ".mark_authorized" do
      let(:private_feed) { create(:private_feed, podcast: podcast) }
      let(:feed_tok) { private_feed.tokens.first }

      it "should add an authorized query param" do
        assert_equal "http://example.com?auth=#{feed_tok.token}", EnclosureUrlBuilder.mark_authorized("http://example.com", private_feed)
      end

      it "should preserve existing query params" do
        assert_equal "http://example.com?foo=bar&auth=#{feed_tok.token}", EnclosureUrlBuilder.mark_authorized("http://example.com?foo=bar", private_feed)
      end

      it "should raise an exception if the private feed has no tokens" do
        private_feed.tokens = []
        err = assert_raises(StandardError) { EnclosureUrlBuilder.mark_authorized("http://example.com", private_feed) }
        assert_equal err.message, "Missing tokens for private feed #{private_feed.id}"
      end
    end
  end
end
