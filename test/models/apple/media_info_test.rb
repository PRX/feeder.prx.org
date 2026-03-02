# frozen_string_literal: true

require "test_helper"

describe Apple::MediaInfo do
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode_with_media, podcast: podcast) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
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

  let(:apple_episode_id) { "apple-ep-id" }
  let(:podcast_container_json_row) do
    {"request_metadata" => {"apple_episode_id" => apple_episode_id},
     "api_response" => {"val" => {"data" =>
     {"type" => "podcastContainers",
      "id" => "1234"}}}}
  end
  let(:pc) { Apple::PodcastContainer.upsert_podcast_container(apple_episode, podcast_container_json_row) }

  def status
    episode.apple_status
  end

  describe ".filename_prefix" do
    it "returns empty string for zero" do
      assert_equal "", Apple::MediaInfo.filename_prefix(0)
    end

    it "returns count prefix for non-zero" do
      assert_equal "3_", Apple::MediaInfo.filename_prefix(3)
    end
  end

  describe ".reset_source_file_metadata" do
    it "persists filename and enclosure_url but does not clear source probe fields" do
      pc # ensure container exists
      assert_equal 0, status&.source_fetch_count.to_i

      Apple::MediaInfo.reset_source_file_metadata([apple_episode])

      episode.apple_update_delivery_status(source_url: "www.some/foo", source_size: 123, source_media_version_id: 1)

      assert_equal 1, status.source_fetch_count
      assert status.source_filename.present?
      assert status.source_url.present?
      assert status.source_size.present?
      assert status.source_media_version_id.present?

      apple_episode.stub(:enclosure_url, "http://something/transistor") do
        apple_episode.stub(:enclosure_filename, "transistor") do
          Apple::MediaInfo.reset_source_file_metadata([apple_episode])
        end
      end

      assert_equal 2, status.source_fetch_count
      assert status.source_filename.present?
      # Probe fields are NOT cleared by reset — they persist until overwritten atomically
      assert status.source_url.present?
      assert status.source_size.present?
      assert status.source_media_version_id.present?

      assert_equal "1_transistor", status.source_filename
      assert_equal "http://something/transistor", status.enclosure_url
    end

    it "increments the source filename" do
      pc # ensure container exists
      assert_equal 0, status&.source_fetch_count.to_i
      Apple::MediaInfo.reset_source_file_metadata([apple_episode])
      episode.apple_update_delivery_status(source_url: "www.some/foo", source_size: 123, source_filename: "foo", source_media_version_id: 1)

      apple_episode.stub(:enclosure_filename, "new") do
        apple_episode.stub(:enclosure_url, "http://this-is-new") do
          assert_equal "foo", status.source_filename
          assert_equal 1, status.source_fetch_count

          Apple::MediaInfo.reset_source_file_metadata([apple_episode])
          assert_equal "1_new", status.source_filename
          assert_equal 2, status.source_fetch_count

          Apple::MediaInfo.reset_source_file_metadata([apple_episode])
          assert_equal "2_new", status.source_filename
          assert_equal 3, status.source_fetch_count
        end
      end
    end

    it "increments the count based on reset count" do
      pc # ensure container exists
      assert_equal 0, status&.source_fetch_count.to_i

      Apple::MediaInfo.reset_source_file_metadata([apple_episode])
      assert_equal 1, status.source_fetch_count

      Apple::MediaInfo.reset_source_file_metadata([apple_episode])
      assert_equal 2, status.source_fetch_count

      Apple::MediaInfo.reset_source_file_metadata([apple_episode])
      assert_equal 3, status.source_fetch_count
    end

    it "filters episodes without a container" do
      apple_episode.stub(:podcast_container, nil) do
        Apple::MediaInfo.reset_source_file_metadata([apple_episode])
        assert_nil status&.source_filename
        assert_equal 0, status&.source_fetch_count.to_i
      end
    end

    it "resets metadata regardless of needs_delivery state" do
      pc # ensure container exists
      Apple::MediaInfo.reset_source_file_metadata([apple_episode])
      episode.apple_update_delivery_status(source_url: "www.some/foo", source_size: 123, source_filename: "foo")

      apple_episode.stub(:enclosure_filename, "new") do
        apple_episode.stub(:enclosure_url, "http://this-is-new") do
          apple_episode.stub(:needs_delivery?, false) do
            Apple::MediaInfo.reset_source_file_metadata([apple_episode])
          end
        end
      end

      # Probe fields are no longer cleared by reset
      refute status.source_url.nil?
      refute status.source_size.nil?
      assert_equal "http://this-is-new", status.enclosure_url
      assert_equal "1_new", status.source_filename
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
