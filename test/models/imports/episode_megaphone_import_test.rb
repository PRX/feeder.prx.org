require "test_helper"

describe EpisodeMegaphoneImport do
  let(:user) { create(:user) }
  let(:podcast) { create(:podcast) }

  let(:importer) { create(:podcast_import, podcast: podcast) }

  let(:entry) do
    {
      id: "this-is-an-episode-guid-12345",
      title: "Sidedoor iTunes title",
      summary: "Sidedoor from the Smithsonian: Shake it Up",
      pubdate: "2022-06-09T20:13:58.000Z",
      season_number: 2,
      episode_number: 4,
      audio_file: "https://upload.prx.org/megaphone/audio.mp3",
      id3_file: "https://upload.prx.org/megaphone/id3.mp3",
      image_file: "https://cdn.prx.org/sidedoor.jpg"
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

    sns.reset
    prev_sns = ENV["PORTER_SNS_TOPIC"]
    ENV["PORTER_SNS_TOPIC"] = "FOO"
    Task.stub :porter_sns_client, sns do
      test.call
    end
    ENV["PORTER_SNS_TOPIC"] = prev_sns
  end

  it "creates an episode on import" do
    episode_import.stub(:put_file, true) do
      episode_import.import!
    end
    f = episode_import.episode
    _(f.description).must_match(/Shake it Up/)
    _(f.title).must_equal "Sidedoor iTunes title"
    _(f.season_number).must_equal 2
    _(f.episode_number).must_equal 4

    # It has the podcast set and the published_at date
    _(f.podcast_id).must_equal podcast.id
    _(f.published_at).must_equal Time.zone.parse("2022-06-09T20:13:58.000Z")

    _(f.uncut).wont_be_nil

    _(f.images.count).must_equal 1

    _(sns.messages.count).must_equal 2

    _(sns.messages.map { |m| m["Job"]["Tasks"].length }).must_equal [2, 3]
    _(sns.messages.map { |m| m["Job"]["Tasks"].map { |v| v["Type"] } }).must_equal [["Inspect", "Copy"], ["Inspect", "Copy", "Waveform"]]
    _(sns.messages.map { |m| m["Job"]["Source"]["Mode"] }).must_equal(["HTTP", "AWS/S3"])

    importer.reload
    _(f.image.status).must_equal "created"
    _(f.uncut.status).must_equal "created"
  end
end
