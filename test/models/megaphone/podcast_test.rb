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
      assert_not_nil dt_podcast.ready_itunes_image.href
      assert_equal podcast.background_image_file_url, dt_podcast.ready_itunes_image.href
      assert podcast.valid?
    end
  end
end
