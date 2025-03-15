require "test_helper"

describe Megaphone::Episode do
  let(:feeder_podcast) { create(:podcast) }
  let(:feed) { create(:megaphone_feed, podcast: feeder_podcast) }
  let(:feeder_episode) { create(:episode, podcast: feeder_podcast, segment_count: 2) }
  let(:media_episode) { create(:episode_with_media, podcast: feeder_podcast) }
  let(:podcast) { Megaphone::Podcast.new_from_feed(feed).tap { |p| p.id = "mp-123-456" } }

  before {
    stub_request(:post, "https://#{ENV["ID_HOST"]}/token")
      .to_return(status: 200,
        body: '{"access_token":"thisisnotatoken","token_type":"bearer"}',
        headers: {"Content-Type" => "application/json; charset=utf-8"})

    stub_request(:get, "https://#{ENV["AUGURY_HOST"]}/api/v1/podcasts/#{feeder_podcast.id}/placements")
      .to_return(status: 200, body: json_file(:placements), headers: {})
  }

  describe "#valid?" do
    it "must have required attributes" do
      episode = Megaphone::Episode.new_from_episode(podcast, feeder_episode)
      assert_not_nil episode
      assert_equal episode.feeder_episode, feeder_episode
      assert_equal episode.private_feed, feed
      assert_equal episode.config, feed.config
      assert_equal episode.title, feeder_episode.title
      assert episode.valid?
    end
  end

  it "can create a arrangement_version_url" do
    episode = Megaphone::Episode.new_from_episode(podcast, feeder_episode)
    location = "https://f.development.prxu.org/8772/d66b53b2-737c-49b0-b2bf-b3ca01199599/17d3420a-8d62-4493-ba9a-6a8675ed205b.mp3"
    media_version = 163842
    count = 1

    url = episode.arrangement_version_url(location, media_version, count)
    assert_equal url, "https://f.development.prxu.org/8772/d66b53b2-737c-49b0-b2bf-b3ca01199599/17d3420a-8d62-4493-ba9a-6a8675ed205b_163842_1.mp3"
  end

  describe "#create!" do
    before {
      stub_request(:post, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/mp-123-456/episodes")
        .to_return(status: 200, body: {id: "megaphone-episode-guid"}.to_json, headers: {})
    }

    it "can create a draft with no audio and mark delivered" do
      refute feeder_episode.complete_media?
      assert_nil feeder_episode.episode_delivery_status(:megaphone)
      assert_nil feeder_episode.sync_log(:megaphone)

      episode = Megaphone::Episode.new_from_episode(podcast, feeder_episode)
      episode.create!

      assert_nil episode.background_audio_file_url
      assert feeder_episode.sync_log(:megaphone).external_id
      assert feeder_episode.episode_delivery_status(:megaphone)
    end

    it "can create a published episode with audio" do
      base_url = "https://dovetail.prxu.org/#{feeder_podcast.id}/#{feed.slug}/#{media_episode.guid}/some-digest-value"
      source_url = "#{base_url}/audio.flac"
      arrangement_url = "#{base_url}/audio_#{media_episode.media_version_id}_0.flac"

      stub_request(:head, "https://dovetail.prxu.org/#{feeder_podcast.id}/#{feed.slug}/#{media_episode.guid}/audio.flac?auth=#{feed.tokens.first.token}").
      to_return(status: 302, body: "", headers: {
        "x-episode-media-version" => media_episode.media_version_id,
        "location" => source_url,
        "content-length" => 1000000
      })

      assert media_episode.complete_media?
      assert_nil media_episode.episode_delivery_status(:megaphone)
      assert_nil media_episode.sync_log(:megaphone)

      episode = Megaphone::Episode.new_from_episode(podcast, media_episode)

      assert_equal media_episode.media_version_id, episode.source_media_version_id
      assert_equal 1000000, episode.source_size
      assert_equal arrangement_url, episode.source_url

      episode.create!

      assert_equal arrangement_url, episode.background_audio_file_url
      assert media_episode.sync_log(:megaphone).external_id
      assert media_episode.episode_delivery_status(:megaphone)
    end

    it "can create a published episodes with the wrong media version from DTR" do
    end
  end

  describe "#delete!" do
    before {
      stub_request(:post, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/mp-123-456/episodes")
        .to_return(status: 200, body: {id: "megaphone-episode-guid"}.to_json, headers: {})

      stub_request(:delete, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/mp-123-456/episodes/megaphone-episode-guid")
        .to_return(status: 200, body: {id: "megaphone-episode-guid"}.to_json, headers: {})
    }

    it "can delete a megaphone episode, delivery status, and sync log" do
      episode = Megaphone::Episode.new_from_episode(podcast, feeder_episode)
      episode.create!

      episode.delete!
      assert_nil feeder_episode.episode_delivery_status(:megaphone)
      assert_nil feeder_episode.sync_log(:megaphone)
    end
  end
end
