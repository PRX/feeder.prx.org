require "test_helper"

class TestHelper
  include PodcastsHelper
end

describe PodcastsHelper do
  let(:helper) { TestHelper.new }
  let(:podcast) { build(:podcast, description: "description") }
  let(:feed1) { podcast.default_feed }
  let(:feed2) { build(:feed, private: true, podcast: podcast, slug: "adfree", episode_footer: "footer", description: "different") }
  let(:episode) { build(:episode, description: "description") }

  describe "#feed_description" do
    it "gets the feed or podcast description" do
      assert_equal "description", feed_description(feed1, podcast)
      assert_equal "different", feed_description(feed2, podcast)
    end
  end

  describe "#episode_description" do
    it "gets the episode description with a footer" do
      assert_equal "description", episode_description(episode, feed1)
      assert_equal "description\n\nfooter", episode_description(episode, feed2)
    end
  end

  describe "#episode_title" do
    it "gets the episode title based on feed type" do
      assert_equal episode.title, episode_title(episode, feed1)

      episode.podcast.stub(:has_apple_feed?, true) do
        episode.stub(:title_safe, "truncated title") do
          assert_equal "truncated title", episode_title(episode, feed1)
        end
      end
    end
  end
end
