require "test_helper"

describe Feed::AppleSubscription do
  let(:podcast) { create(:podcast) }
  let(:feed_1) { podcast.default_feed }
  let(:apple_feed) { build(:apple_feed, podcast: podcast) }

  describe "#valid?" do
    it "cannot change the default properties once saved" do
      apple_feed.title = "new apple feed"
      apple_feed.slug = "new-apple-slug"
      apple_feed.file_name = "new_file.xml"
      apple_feed.audio_format = {f: "flac", b: 16, c: 2, s: 44100}
      assert apple_feed.valid?
      apple_feed.save!

      apple_feed.title = "changed apple feed"
      refute apple_feed.valid?
      apple_feed.title = "new apple feed"
      assert apple_feed.valid?

      apple_feed.slug = "changed-apple-slug"
      refute apple_feed.valid?
      apple_feed.slug = "new-apple-slug"
      assert apple_feed.valid?

      apple_feed.file_name = "changed_file_name.xml"
      refute apple_feed.valid?
      apple_feed.file_name = "new_file.xml"
      assert apple_feed.valid?

      apple_feed.audio_format = {f: "wav", b: 128, c: 2, s: 44100}
      refute apple_feed.valid?
      apple_feed.audio_format = {f: "flac", b: 16, c: 2, s: 44100}
      assert apple_feed.valid?
    end

    it "cannot have more than one apple feed on a single podcast" do
      second_apple = build(:apple_feed, podcast: podcast)
      assert second_apple.valid?

      apple_feed.save!
      assert apple_feed.valid?
      refute second_apple.valid?
    end

    it "must be a private feed" do
      apple_feed.private = false
      refute apple_feed.valid?
    end
  end

  describe "#apple_configs" do
    it "has apple credentials" do
      assert apple_feed.apple_config.present?
      assert apple_feed.apple_config.valid?

      apple_feed.save!
      assert_equal feed_1, apple_feed.apple_config.public_feed
    end
  end

  describe "#publish_to_apple?" do
    it "returns true if the feed has apple credentials" do
      apple_feed.save!

      refute feed_1.publish_to_apple?
      assert apple_feed.publish_to_apple?
    end

    it "returns false if the creds are not marked publish_enabled?" do
      apple_feed.apple_config.publish_enabled = false
      apple_feed.save!
      refute apple_feed.publish_to_apple?
    end

    it "returns false if the feed is not an Apple Subscription feed" do
      refute_equal feed_1.type, "Feed::AppleSubscription"
      refute feed_1.publish_to_apple?
    end
  end
end
