require "test_helper"

describe Feeds::AppleSubscription do
  let(:podcast) { create(:podcast, default_feed: default_feed) }
  let(:default_feed) { build(:default_feed, audio_format: nil) }
  let(:apple_feed) { build(:apple_feed, podcast: podcast) }

  describe "#set_defaults" do
    let(:default_feed) { build_stubbed(:feed, display_episodes_count: 99, audio_format: nil) }
    let(:podcast) { build_stubbed(:podcast, default_feed: default_feed) }

    it "sets default values for apple subscription feeds" do
      f = Feeds::AppleSubscription.new(podcast: podcast)

      assert_equal Feeds::AppleSubscription::DEFAULT_FEED_SLUG, f.slug
      assert_equal Feeds::AppleSubscription::DEFAULT_TITLE, f.title
      assert_equal Feeds::AppleSubscription::DEFAULT_AUDIO_FORMAT, f.audio_format
      assert_equal 99, f.display_episodes_count
      assert_equal Feeds::AppleSubscription::DEFAULT_ZONES, f.include_zones
      assert_equal true, f.private

      assert_equal 1, f.tokens.length
      assert_equal Feeds::AppleSubscription::DEFAULT_TITLE, f.tokens[0].label
    end

    it "does not override most existing values" do
      t = FeedToken.new(label: "l1", token: "t1")
      f = Feeds::AppleSubscription.new(
        podcast: podcast,
        slug: "foo",
        title: "bar",
        audio_format: {f: "flac"},
        display_episodes_count: 88,
        include_zones: ["something"],
        private: false,
        tokens: [t]
      )

      assert_equal "foo", f.slug
      assert_equal "bar", f.title
      assert_equal "flac", f.audio_format[:f]
      assert_equal 88, f.display_episodes_count
      assert_equal ["something"], f.include_zones
      assert_equal true, f.private

      assert_equal 1, f.tokens.length
      assert_equal "l1", f.tokens[0].label
      assert_equal "t1", f.tokens[0].token
    end
  end

  describe "#guess_audio_format" do
    it "uses the default feed format" do
      default_feed.audio_format = {f: "mp3", b: 192, c: 1, s: 48000}
      assert_equal default_feed.audio_format, apple_feed.guess_audio_format
    end

    it "uses the max episode format" do
      c1 = build(:content, mime_type: "audio/mpeg", bit_rate: 192, channels: 1, sample_rate: 22050)
      c2 = build(:content, mime_type: "audio/mpeg", bit_rate: 64, channels: 2, sample_rate: 44100)
      c3 = build(:content, mime_type: "audio/wav", bit_rate: 16, channels: 1, sample_rate: 48000)
      create(:episode, podcast: podcast, contents: [c1])
      create(:episode, podcast: podcast, contents: [c2])
      create(:episode, podcast: podcast, contents: [c3])

      assert_nil default_feed.audio_format
      assert_equal ({"f" => "mp3", "b" => 192, "c" => 2, "s" => 44100}), apple_feed.guess_audio_format
    end

    it "falls back to the default format" do
      assert_equal Feeds::AppleSubscription::DEFAULT_AUDIO_FORMAT, apple_feed.guess_audio_format
    end
  end

  describe "#valid?" do
    it "cannot change the default properties once saved" do
      apple_feed.title = "new apple feed"
      apple_feed.slug = "new-apple-slug"
      apple_feed.file_name = "new_file.xml"
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

    it "must have a token" do
      apple_feed.tokens = []
      refute apple_feed.valid?
    end
  end

  describe "#apple_configs" do
    it "has apple credentials" do
      assert apple_feed.apple_config.present?
      assert apple_feed.apple_config.valid?

      apple_feed.save!
      assert_equal default_feed, apple_feed.apple_config.public_feed
    end

    it "can return a list of possible apple shows" do
      body = {
        "data":[
          {"id" => "1", "attributes" => { "title" => "t1" }},
          {"id" => "2", "attributes" => { "title" => "t2"}}
        ],
        "links": {}
      }.to_json
      stub_request(:get, "https://api.podcastsconnect.apple.com/v1/shows").to_return(status: 200, body: body)
      assert_equal apple_feed.apple_show_options, [["1 (t1)", "1"], ["2 (t2)", "2"]]
    end
  end

  describe "#publish_to_apple?" do
    it "returns true if the feed has apple credentials" do
      apple_feed.save!

      refute default_feed.publish_to_apple?
      assert apple_feed.publish_to_apple?
    end

    it "returns false if the creds are not marked publish_enabled?" do
      apple_feed.apple_config.publish_enabled = false
      apple_feed.save!
      refute apple_feed.publish_to_apple?
    end

    it "returns false if the feed is not an Apple Subscription feed" do
      refute_equal default_feed.type, "Feeds::AppleSubscription"
      refute default_feed.publish_to_apple?
    end
  end
end
