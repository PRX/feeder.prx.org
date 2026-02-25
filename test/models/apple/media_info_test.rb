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

  describe ".from_delivery_status" do
    it "builds a MediaInfo from persisted delivery status" do
      episode.apple_update_delivery_status(
        source_media_version_id: episode.media_version_id,
        source_size: 2000,
        source_url: "https://cdn.example.com/persisted.mp3"
      )

      mi = Apple::MediaInfo.from_delivery_status(apple_episode)
      assert_equal apple_episode, mi.episode
      assert_equal episode.media_version_id, mi.source_media_version_id
      assert_equal 2000, mi.source_size
      assert_equal "https://cdn.example.com/persisted.mp3", mi.source_url
    end

    it "handles nil delivery status gracefully" do
      mi = Apple::MediaInfo.from_delivery_status(apple_episode)
      assert_nil mi.source_media_version_id
      assert_nil mi.source_size
      assert_nil mi.source_url
    end
  end

  describe ".complete_from_delivery_status?" do
    it "returns true when media version matches and all source attrs present" do
      episode.apple_update_delivery_status(
        source_media_version_id: episode.media_version_id,
        source_size: 2000,
        source_url: "https://cdn.example.com/audio.mp3"
      )
      assert Apple::MediaInfo.complete_from_delivery_status?(apple_episode)
    end

    it "returns false when source_url is nil" do
      episode.apple_update_delivery_status(
        source_media_version_id: episode.media_version_id,
        source_size: 2000,
        source_url: nil
      )
      refute Apple::MediaInfo.complete_from_delivery_status?(apple_episode)
    end

    it "returns false when source_size is nil" do
      episode.apple_update_delivery_status(
        source_media_version_id: episode.media_version_id,
        source_size: nil,
        source_url: "https://cdn.example.com/audio.mp3"
      )
      refute Apple::MediaInfo.complete_from_delivery_status?(apple_episode)
    end

    it "returns false when media version does not match" do
      episode.apple_update_delivery_status(
        source_media_version_id: -1,
        source_size: 2000,
        source_url: "https://cdn.example.com/audio.mp3"
      )
      refute Apple::MediaInfo.complete_from_delivery_status?(apple_episode)
    end
  end
end
