require "test_helper"

describe Megaphone::Episode do
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:megaphone_feed, podcast: podcast) }
  let(:dt_episode) { create(:episode, podcast: podcast) }

  describe "#valid?" do
    it "must have required attributes" do
      episode = Megaphone::Episode.new_from_episode(dt_episode, feed)
      assert_not_nil episode
      assert_not_nil episode.episode
      assert_not_nil episode.feed
      assert_equal episode.title, dt_episode.title
      assert episode.valid?
    end
  end
end
