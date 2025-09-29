require "test_helper"

describe EpisodeMegaphoneImport do
  let(:user) { create(:user) }
  let(:default_feed) { create(:default_feed, audio_format: nil) }
  let(:podcast) { create(:podcast, default_feed: default_feed) }
  let(:megaphone_feed) { create(:megaphone_feed, podcast: podcast) }

  let(:importer) { create(:podcast_megaphone_import, podcast: podcast, override_enclosures: true) }

  let(:entry) do
    {
      id: "this-is-an-episode-guid-12345",
      uid: "SD8181225225",
      title: "Sidedoor iTunes title",
      summary: "Sidedoor from the Smithsonian: Shake it Up",
      pubdate: "2022-06-09T20:13:58.000Z",
      season_number: 2,
      episode_number: 4,
      audio_file: "https://upload.prx.org/megaphone/audio.mp3",
      size: 123000,
      id3_file: "https://upload.prx.org/megaphone/id3.mp3",
      id3_file_size: 123,
      image_file: "https://cdn.prx.org/sidedoor.jpg",
      download_url: "https://megaphone.link/XYZ123",
      duration: "1234",
      bitrate: "64",
      samplerate: "44100",
      channel_mode: "stereo",
      insertion_points: [30.0]
    }
  end

  let(:episode_import) do
    EpisodeMegaphoneImport.create!(
      podcast_import: importer,
      entry: entry,
      guid: "this-is-an-episode-guid-12345"
    )
  end

  let(:sns) { SnsMock.new }

  around do |test|
    stub_request(:get, "https://upload.prx.org/megaphone/id3.mp3")
      .to_return(status: 200, body: "id3filecontents", headers: {})

    stub_request(:get, "https://upload.prx.org/megaphone/audio.mp3")
      .to_return(status: 200, body: "audiofilecontents", headers: {})

    stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts?externalId=95ebfb22-0002-5f78-a7aa-5acb5ac7daa9")
      .to_return(status: 200, body: [{id: "DEF67890", updatedAt: "2024-11-03T14:54:02.690Z"}].to_json, headers: {})

    stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/DEF67890/episodes/#{entry[:id]}")
      .to_return(status: 200, body: [{id: entry[:id], updatedAt: "2024-11-03T14:54:02.690Z"}].to_json, headers: {})

    stub_request(:put, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/DEF67890/episodes/#{entry[:id]}")
      .to_return(status: 200, body: "{}", headers: {})

    stub_request(:post, "https://#{ENV["ID_HOST"]}/token")
      .to_return(status: 200,
        body: '{"access_token":"thisisnotatoken","token_type":"bearer"}'.freeze,
        headers: {"Content-Type" => "application/json; charset=utf-8"})

    stub_request(:get, "https://#{ENV["AUGURY_HOST"]}/api/v1/podcasts/#{podcast.id}/placements")
      .to_return(status: 200, body: json_file(:placements), headers: {})

    sns.reset
    prev_sns = ENV["PORTER_SNS_TOPIC"]
    ENV["PORTER_SNS_TOPIC"] = "FOO"
    Task.stub :porter_sns_client, sns do
      test.call
    end
    ENV["PORTER_SNS_TOPIC"] = prev_sns
  end

  it "creates an episode on import" do
    _(megaphone_feed.podcast).must_equal podcast

    episode_import.stub(:put_file, true) do
      episode_import.import!
    end

    episode = episode_import.episode
    _(episode.description).must_match(/Shake it Up/)
    _(episode.title).must_equal "Sidedoor iTunes title"
    _(episode.season_number).must_equal 2
    _(episode.episode_number).must_equal 4

    # It has the podcast set and the published_at date
    _(episode.podcast_id).must_equal podcast.id
    _(episode.published_at).must_equal Time.zone.parse("2022-06-09T20:13:58.000Z")

    _(episode.uncut).wont_be_nil

    _(episode.images.count).must_equal 1

    _(sns.messages.count).must_equal 2

    _(sns.messages.map { |m| m["Job"]["Tasks"].length }).must_equal [2, 3]
    _(sns.messages.map { |m| m["Job"]["Tasks"].map { |v| v["Type"] } }).must_equal [["Inspect", "Copy"], ["Inspect", "Copy", "Waveform"]]
    _(sns.messages.map { |m| m["Job"]["Source"]["Mode"] }).must_equal(["HTTP", "AWS/S3"])

    importer.reload
    _(episode.image.status).must_equal "created"
    _(episode.uncut.status).must_equal "created"

    # Status is null on initial import
    _(episode.episode_delivery_status(:megaphone)).must_be_nil

    # mark the uncut as complete, as if copy media task processed
    episode.uncut.status = "complete"
    episode.uncut.mime_type = "audio/mpeg"
    episode.uncut.medium = "audio"
    episode.uncut.file_size = 123000
    episode.uncut.sample_rate = 44100
    episode.uncut.channels = 2
    episode.uncut.duration = 1234.0
    episode.uncut.bit_rate = 64
    episode.uncut.save!
    episode.uncut.slice_contents!

    # now we'll update the 2 contents sliced from the uncut
    segment_1 = episode.contents.first
    segment_1.status = "complete"
    segment_1.mime_type = "audio/mpeg"
    segment_1.medium = "audio"
    segment_1.file_size = 1000
    segment_1.sample_rate = 44100
    segment_1.channels = 2
    segment_1.duration = 10.0
    segment_1.bit_rate = 64
    segment_1.save!

    segment_2 = episode.contents.second
    segment_2.status = "complete"
    segment_2.mime_type = "audio/mpeg"
    segment_2.medium = "audio"
    segment_2.file_size = 122000
    segment_2.sample_rate = 44100
    segment_2.channels = 2
    segment_2.duration = 1224.0
    segment_2.bit_rate = 64
    segment_2.save!

    base_url = "https://dovetail.prxu.org/#{podcast.id}/#{megaphone_feed.slug}/#{episode.guid}/some-digest-value"
    source_url = "#{base_url}/audio.mp3"

    stub_request(:head, "https://dovetail.prxu.org/#{podcast.id}/#{megaphone_feed.slug}/#{episode.guid}/#{entry[:id]}.mp3?auth=#{megaphone_feed.tokens.first.token}")
      .to_return(status: 302, body: "", headers: {
        "x-episode-media-version" => episode.media_version_id - 1,
        "location" => source_url,
        "content-length" => 123000
      })

    _(episode.media_ready?).must_equal true
    episode_import.finish_sync!
    delivery_status = episode.episode_delivery_status(:megaphone)
    sync_log = episode.sync_log(:megaphone)

    _(delivery_status).wont_be_nil
    _(delivery_status.source_filename).must_match(/_#{episode.media_version_id}\.mp3/)
    _(delivery_status.source_size).must_equal 123123
    _(delivery_status.source_media_version_id).must_equal episode.media_version_id
    _(delivery_status.uploaded).must_equal true
    _(delivery_status.delivered).must_equal true

    _(sync_log).wont_be_nil
    _(sync_log.external_id).must_equal entry[:id]
  end
end
