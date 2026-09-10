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
      assert_equal Feeds::AppleSubscription::DEFAULT_LABEL, f[:label]
      assert_equal Feeds::AppleSubscription::DEFAULT_AUDIO_FORMAT, f.audio_format
      assert_equal 99, f.display_episodes_count
      assert_equal Feeds::AppleSubscription::DEFAULT_ZONES, f.include_zones
      assert_equal true, f.private

      assert f.valid?
      assert_equal 1, f.tokens.length
      assert_equal Feeds::AppleSubscription::DEFAULT_LABEL, f.tokens[0].label
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
  end

  describe "#delegated_delivery_config" do
    it "has apple credentials" do
      assert apple_feed.delegated_delivery_config.present?
      assert apple_feed.delegated_delivery_config.valid?

      apple_feed.save!
      assert_equal default_feed, apple_feed.delegated_delivery_config.public_feed
    end

    it "can return a list of possible apple shows" do
      body = {data: [{id: "1", attributes: {title: "t1"}}, {id: "2", attributes: {title: "t2"}}], links: {}}.to_json
      stub_request(:get, "https://aardvark.prx.org/shows").to_return(status: 200, body: body)
      assert_equal apple_feed.apple_show_options, [["1 (t1)", "1"], ["2 (t2)", "2"]]
    end
  end

  describe "#integration_draft_episodes" do
    [-1.day.to_i, 0, 1.day.to_i].each do |offset|
      it "partitions episodes at the release boundary with offset #{offset}" do
        freeze_time do
          apple_feed.update!(episode_offset_seconds: offset, display_episodes_count: nil)
          cutoff = Time.current - offset
          released = create(:episode, podcast: podcast, published_at: cutoff - 1.second)
          boundary = create(:episode, podcast: podcast, published_at: cutoff)
          upcoming = create(:episode, podcast: podcast, published_at: cutoff + 1.second)
          draft = create(:episode, podcast: podcast, published_at: nil)

          assert_equal [boundary.id, released.id].sort, apple_feed.feed_episode_ids.sort
          assert_equal [upcoming.id, draft.id].sort, apple_feed.integration_draft_episodes.pluck(:id).sort
        end
      end
    end

    it "returns draft and scheduled episodes" do
      apple_feed.save!
      draft = create(:episode, podcast: podcast, published_at: nil)
      scheduled = create(:episode, podcast: podcast, published_at: 1.day.from_now)
      published = create(:episode, podcast: podcast, published_at: 1.day.ago)

      result = apple_feed.integration_draft_episodes
      assert_includes result, draft
      assert_includes result, scheduled
      refute_includes result, published
    end
  end

  describe "#integration_episode?" do
    it "keeps early releases beyond the feed limit out of both episode sets" do
      apple_feed.update!(episode_offset_seconds: -1.day.to_i, display_episodes_count: 1)
      excluded = create(:episode_with_media, podcast: podcast, published_at: 1.hour.from_now)
      included = create(:episode_with_media, podcast: podcast, published_at: 2.hours.from_now)

      assert_equal [included.id], apple_feed.feed_episode_ids
      assert_empty apple_feed.integration_draft_episodes
      refute apple_feed.integration_episode?(excluded)
      assert apple_feed.integration_episode?(included)
    end

    it "returns true for published episodes in feed_episodes" do
      apple_feed.save!
      published = create(:episode, podcast: podcast, published_at: 1.hour.ago)

      assert apple_feed.integration_episode?(published)
    end

    it "returns false for published episodes not in feed_episodes" do
      apple_feed.save!
      published = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      # remove from the apple feed's episodes
      apple_feed.episodes_feeds.where(episode: published).delete_all

      refute apple_feed.integration_episode?(published)
    end

    it "returns true for draft and scheduled episodes with uploadable media" do
      apple_feed.save!
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      scheduled = create(:episode_with_media, podcast: podcast, published_at: 1.day.from_now)

      assert apple_feed.integration_episode?(draft)
      assert apple_feed.integration_episode?(scheduled)
    end

    it "returns false for draft episodes with no media" do
      apple_feed.save!
      no_media = create(:episode, podcast: podcast, published_at: nil)

      refute apple_feed.integration_episode?(no_media)
    end

    it "returns false for draft episodes with incomplete media (enclosure not complete)" do
      apple_feed.save!
      processing = create(:episode,
        podcast: podcast,
        published_at: nil,
        medium: "audio",
        segment_count: 1,
        contents: [build(:content, status: "processing")])

      # enclosure_ready?(false) would be true, but enclosure_ready?(true) is false
      assert processing.enclosure_ready?(false)
      refute processing.enclosure_ready?(true)
      refute apple_feed.integration_episode?(processing)
    end

    it "returns false for draft episodes that are not feed-ready" do
      apple_feed.save!
      not_ready = create(:episode,
        podcast: podcast,
        published_at: nil,
        medium: "audio",
        segment_count: 1,
        contents: [build(:content, status: "created")])

      refute apple_feed.integration_episode?(not_ready)
    end

    it "returns false for draft episodes not assigned to this feed" do
      apple_feed.save!
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      # verify it's initially included
      assert apple_feed.integration_episode?(draft)

      # remove from the apple feed
      apple_feed.episodes_feeds.where(episode: draft).delete_all
      apple_feed.reload

      refute apple_feed.integration_episode?(draft)
    end
  end

  describe "#update_apple_show" do
    it "creates and updates the show feed binding" do
      apple_feed.save!

      apple_feed.update!(apple_show_id: "show-1")

      binding = default_feed.reload.apple_show_feed_binding
      assert_equal binding, apple_feed.delegated_delivery_config.reload.show_feed_binding
      assert_equal apple_feed.delegated_delivery_config.key, podcast.reload.apple_key
      assert_equal "show-1", binding.apple_show_id

      assert_no_difference "Apple::ShowFeedBinding.count" do
        apple_feed.update!(apple_show_id: "show-2")
      end

      assert_equal "show-2", binding.reload.apple_show_id
    end

    it "removes the show feed binding when the apple show id is cleared" do
      apple_feed.save!
      apple_feed.update!(apple_show_id: "show-1")
      assert default_feed.reload.apple_show_feed_binding

      apple_feed.update!(apple_show_id: nil)

      assert_nil default_feed.reload.apple_show_feed_binding
      assert_nil apple_feed.delegated_delivery_config.reload.show_feed_binding
    end
  end

  describe "#publish_to_apple?" do
    it "returns true if the feed has apple credentials" do
      apple_feed.save!

      refute default_feed.publish_to_apple?
      assert apple_feed.publish_to_apple?
    end

    it "returns false if the creds are not marked publish_enabled?" do
      apple_feed.delegated_delivery_config.publish_enabled = false
      apple_feed.save!
      refute apple_feed.publish_to_apple?
    end

    it "returns false if the feed is not an Apple Subscription feed" do
      refute_equal default_feed.type, "Feeds::AppleSubscription"
      refute default_feed.publish_to_apple?
    end
  end
end
