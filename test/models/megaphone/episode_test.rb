require "test_helper"

describe Megaphone::Episode do
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:megaphone_feed, podcast: podcast) }
  let(:feeder_episode) { create(:episode, podcast: podcast) }

  describe "#valid?" do
    it "must have required attributes" do
      episode = Megaphone::Episode.new_from_episode(feed, feeder_episode)
      assert_not_nil episode
      assert_equal episode.feeder_episode, feeder_episode
      assert_equal episode.private_feed, feed
      assert_equal episode.config, feed.config
      assert_equal episode.title, feeder_episode.title
      assert episode.valid?
    end
  end
end
