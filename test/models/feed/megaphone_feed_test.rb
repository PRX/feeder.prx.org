require "test_helper"

describe Feeds::MegaphoneFeed do
  let(:podcast) { create(:podcast, default_feed: default_feed) }
  let(:default_feed) { build(:default_feed, audio_format: nil) }
  let(:megaphone_feed) { build(:megaphone_feed, podcast: podcast) }

  it "sets the audio format to the default" do
    mf = Feeds::MegaphoneFeed.new(podcast: podcast)
    assert_equal mf.audio_format, Feeds::MegaphoneFeed::DEFAULT_AUDIO_FORMAT
  end

  it "validates audio format must be mp3" do
    mf = build(:megaphone_feed, podcast: podcast, audio_format: {f: "flac", b: 16, c: 2, s: 44100})
    assert_equal mf.audio_format[:f], "flac"
    refute mf.valid?
    assert_includes mf.errors[:audio_format], "must be mp3"
  end

  it "marks the Megaphone delivery status as not delivered" do
    episode = create(:episode, podcast: podcast)
    create(:megaphone_episode_delivery_status, episode: episode, delivered: true, uploaded: true)

    megaphone_feed.mark_as_not_delivered!(episode)

    status = Megaphone::EpisodeDeliveryStatus.current(episode)
    refute status.delivered?
    refute status.uploaded?
  end

  it "builds the Megaphone publisher with the heartbeat block" do
    publisher = Minitest::Mock.new
    publisher.expect(:publish!, :published)
    heartbeat_block = -> {}
    build = ->(feed, heartbeat:) {
      assert_equal megaphone_feed, feed
      assert_same heartbeat_block, heartbeat
      publisher
    }

    megaphone_feed.stub(:publish_integration?, true) do
      Megaphone::Publisher.stub(:new, build) do
        assert_equal :published, megaphone_feed.publish_integration!(&heartbeat_block)
      end
    end

    publisher.verify
  end
end
