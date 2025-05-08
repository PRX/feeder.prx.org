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

    url = episode.arrangement_version_url(location, media_version)
    assert_equal url, "https://f.development.prxu.org/8772/d66b53b2-737c-49b0-b2bf-b3ca01199599/17d3420a-8d62-4493-ba9a-6a8675ed205b_163842.mp3"
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
      source_url = "#{base_url}/audio.mp3"
      arrangement_filename = "audio_#{media_episode.media_version_id}.mp3"
      arrangement_url = "#{base_url}/#{arrangement_filename}"

      stub_request(:head, "https://dovetail.prxu.org/#{feeder_podcast.id}/#{feed.slug}/#{media_episode.guid}/audio.mp3?auth=#{feed.tokens.first.token}")
        .to_return(status: 302, body: "", headers: {
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
      status = media_episode.episode_delivery_status(:megaphone)
      assert status
      # we saved the background audio url to mp, so it is uploaded
      assert status.uploaded
      assert_equal status.source_filename, "audio_#{media_episode.media_version_id}.mp3"
      assert_equal status.source_size, 1000000
      assert_equal status.source_media_version_id, media_episode.media_version_id

      # but we still need to see if it has been fully processed
      refute media_episode.episode_delivery_status(:megaphone).delivered

      # now let's check to see if it is ready on megaphone! (it's not)
      audio_processing_json = <<~JSON
        {
          "originalFilename": "#{arrangement_filename}",
          "audioFileProcessing": true,
          "audioFileStatus": "processing"
        }
      JSON

      stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/mp-123-456/episodes/megaphone-episode-guid")
        .to_return(status: 200, body: audio_processing_json, headers: {})

      episode.check_audio!
      refute media_episode.episode_delivery_status(:megaphone).delivered

      # let's check again to see if it is ready on megaphone! (it is)
      audio_ready_json = <<~JSON
        {
          "originalFilename": "#{arrangement_filename}",
          "audioFileProcessing": false,
          "audioFileStatus": "success",
          "audioFileUpdatedAt": "#{(DateTime.now + 5.minutes).utc.iso8601}"
        }
      JSON

      stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/mp-123-456/episodes/megaphone-episode-guid")
        .to_return(status: 200, body: audio_ready_json, headers: {})

      cp_json = "[{\"cuepointType\":\"postroll\",\"adCount\":1,\"startTime\":\"48.0\",\"adSources\":[\"promo\"],\"action\":\"insert\",\"isActive\":true,\"maxDuration\":120}]"
      stub_request(:put, "https://cms.megaphone.fm/api/episodes/megaphone-episode-guid/cuepoints_batch")
        .with(body: cp_json)
        .to_return(status: 200, body: cp_json, headers: {})

      episode.check_audio!
      assert media_episode.episode_delivery_status(:megaphone).delivered
    end

    it "can create a published episodes with the wrong media version from DTR" do
      base_url = "https://dovetail.prxu.org/#{feeder_podcast.id}/#{feed.slug}/#{media_episode.guid}/some-digest-value"
      source_url = "#{base_url}/audio.mp3"

      stub_request(:head, "https://dovetail.prxu.org/#{feeder_podcast.id}/#{feed.slug}/#{media_episode.guid}/audio.mp3?auth=#{feed.tokens.first.token}")
        .to_return(status: 302, body: "", headers: {
          "x-episode-media-version" => media_episode.media_version_id - 1,
          "location" => source_url,
          "content-length" => 1000000
        })

      assert media_episode.complete_media?
      assert_nil media_episode.episode_delivery_status(:megaphone)
      assert_nil media_episode.sync_log(:megaphone)

      episode = Megaphone::Episode.new_from_episode(podcast, media_episode)

      assert_nil episode.source_media_version_id
      assert_nil episode.source_size
      assert_nil episode.source_url

      episode.create!

      assert_nil episode.background_audio_file_url
      assert media_episode.sync_log(:megaphone).external_id
      assert media_episode.episode_delivery_status(:megaphone)
      # we did not save the background audio url to mp, so it is not uploaded
      refute media_episode.episode_delivery_status(:megaphone).uploaded
      # and likewise not delivered, as we still need to check and wait on DTR
      refute media_episode.episode_delivery_status(:megaphone).delivered
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
