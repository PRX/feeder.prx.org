require "test_helper"

class TestHelper
  attr_accessor :prx_jwt
  include EmbedPlayerHelper
end

describe EmbedPlayerHelper do
  let(:helper) { TestHelper.new }
  let(:episode) { build_stubbed(:episode, podcast: podcast) }
  let(:podcast) { build_stubbed(:podcast, default_feed: feed) }
  let(:feed) { build_stubbed(:feed, enclosure_template: template, enclosure_prefix: prefix) }
  let(:template) { "https://dovetail.prx.test/{slug}/{guid}/ep.mp3" }
  let(:prefix) { "https://dts.podtrac.com/redirect.mp3" }

  before { helper.prx_jwt = "abcd1234" }

  describe "#enclosure_with_token" do
    it "uses the base enclosure with a jwt query param" do
      url = helper.enclosure_with_token(episode)
      assert_includes url, "https://dovetail.prx.test/#{podcast.id}/#{episode.guid}/ep.mp3"
      assert_includes url, "?_t=abcd1234"
      refute_includes url, "podtrac"
    end

    it "handles enclosures with query params" do
      feed.enclosure_template = "https://dovetail/{guid}/ep.mp3?foo=bar"
      url = helper.enclosure_with_token(episode)
      assert_includes url, "?foo=bar&_t=abcd1234"
    end
  end
end
