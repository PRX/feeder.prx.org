require "test_helper"

describe Megaphone::Podcast do
  let(:dt_podcast) { create(:podcast) }
  let(:feed) { create(:megaphone_feed, podcast: dt_podcast) }

  describe "#valid?" do
    it "must have required attributes" do
      podcast = Megaphone::Podcast.new_from_feed(feed)
      assert_not_nil podcast
      assert_not_nil podcast.config
      assert_equal podcast.title, dt_podcast.title
      assert podcast.valid?
    end
  end
end
