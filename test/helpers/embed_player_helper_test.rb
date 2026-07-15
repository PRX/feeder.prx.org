require "test_helper"

class TestHelper
  attr_accessor :prx_jwt
  include EmbedPlayerHelper
end

describe EmbedPlayerHelper do
  let(:helper) { TestHelper.new }
  let(:episode) { build_stubbed(:episode, podcast: podcast) }
  let(:podcast) { build_stubbed(:podcast) }
  let(:dt_host) { ENV["DOVETAIL_HOST"] }

  before { helper.prx_jwt = "abcd1234" }

  describe "#enclosure_with_token" do
    it "uses the base enclosure with a jwt query param" do
      url = helper.enclosure_with_token(episode)
      assert_equal "https://#{dt_host}/#{podcast.id}/#{episode.guid}/ep.mp3?_t=abcd1234", url

      # don't include prefixes
      podcast.default_feed.enclosure_prefix = "http://dont.include/this/"
      url = helper.enclosure_with_token(episode)
      assert_equal "https://#{dt_host}/#{podcast.id}/#{episode.guid}/ep.mp3?_t=abcd1234", url
    end
  end
end
