require "test_helper"

describe Megaphone::Episode do
  let(:feeder_podcast) { create(:podcast) }
  let(:feed) { create(:megaphone_feed, podcast: feeder_podcast) }
  let(:feeder_episode) { create(:episode, podcast: feeder_podcast, segment_count: 2) }
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
    it "can create a published episodes with audio" do
    end
    it "can create a published episodes with the wrong media version from DTR" do
    end
  end
end
