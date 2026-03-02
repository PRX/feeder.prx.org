# frozen_string_literal: true

require "test_helper"

describe Apple::MediaInfo do
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode_with_media, podcast: podcast) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:feed, podcast: podcast, private: true) }
  let(:apple_config) { build(:apple_config) }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }
  let(:apple_show) { Apple::Show.new(api: apple_api, public_feed: public_feed, private_feed: private_feed) }
  let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

  describe "#has_media_version?" do
    it "returns true when source_media_version_id matches episode media_version_id" do
      mi = Apple::MediaInfo.new(
        episode: apple_episode,
        source_media_version_id: episode.media_version_id,
        source_size: 1000,
        source_url: "https://cdn.example.com/audio.mp3"
      )
      assert mi.has_media_version?
    end

    it "returns false when source_media_version_id does not match" do
      mi = Apple::MediaInfo.new(
        episode: apple_episode,
        source_media_version_id: -1,
        source_size: 1000,
        source_url: "https://cdn.example.com/audio.mp3"
      )
      refute mi.has_media_version?
    end

    it "returns false when source_media_version_id is nil" do
      mi = Apple::MediaInfo.new(
        episode: apple_episode,
        source_media_version_id: nil,
        source_size: 1000,
        source_url: "https://cdn.example.com/audio.mp3"
      )
      refute mi.has_media_version?
    end
  end

  describe "#source_attributes" do
    it "returns a hash of source fields" do
      mi = Apple::MediaInfo.new(
        episode: apple_episode,
        source_media_version_id: 42,
        source_size: 1000,
        source_url: "https://cdn.example.com/audio.mp3"
      )
      expected = {source_media_version_id: 42, source_size: 1000, source_url: "https://cdn.example.com/audio.mp3"}
      assert_equal expected, mi.source_attributes
    end
  end

end
