require "test_helper"

describe EpisodeRssImport do
  let(:user) { create(:user) }
  let(:podcast) { create(:podcast) }

  let(:importer) { create(:podcast_rss_import, podcast: podcast) }

  let(:feed) { Feedjira.parse(test_file("/fixtures/transistor_two.xml")) }
  let(:entry) { feed.entries.first }
  let(:entry_libsyn) { feed.entries.last }

  let(:episode_import) do
    EpisodeRssImport.create!(
      podcast_import: importer,
      entry: entry.to_h,
      guid: "https://transistor.prx.org/?p=1286"
    )
  end

  let(:libsyn_episode_import) do
    EpisodeRssImport.create!(
      podcast_import: importer,
      entry: entry.to_h,
      guid: "https://transistor.prx.org/?p=1287"
    )
  end

  let(:sns) { SnsMock.new }

  before do
    stub_requests
  end

  around do |test|
    sns.reset
    prev_sns = ENV["PORTER_SNS_TOPIC"]
    ENV["PORTER_SNS_TOPIC"] = "FOO"
    Task.stub :porter_sns_client, sns do
      test.call
    end
    ENV["PORTER_SNS_TOPIC"] = prev_sns
  end

  it "creates an episode on import" do
    episode_import.import!
    f = episode_import.episode
    _(f.description).must_match(/For the next few episodes/)
    _(f.description).wont_match(/feedburner/)
    _(f.clean_title).must_equal "Sidedoor iTunes title"
    _(f.season_number).must_equal 2
    _(f.episode_number).must_equal 4

    # categories and itunes:keywords are combined
    _(f.categories).must_equal ["Indie Features", "science", "architecture", "keyword1"]

    # It has the podcast set and the published_at date
    _(f.podcast_id).must_equal podcast.id
    _(f.published_at).must_equal Time.zone.parse("2017-01-20 03:04:12")

    _(f.contents.count).must_equal 1
    _(f.contents.first.status).must_equal "created"

    _(f.images.count).must_equal 1

    _(sns.messages.count).must_equal 2
    _(sns.messages.map { |m| m["Job"]["Tasks"].length }).must_equal [2, 2]
    _(sns.messages.map { |m| m["Job"]["Tasks"].map { |v| v["Type"] } }).must_equal [["Inspect", "Copy"], ["Inspect", "Copy"]]
    _(sns.messages.map { |m| m["Job"]["Source"] })
      .must_equal([
        {"Mode" => "HTTP", "URL" => "https://dts.podtrac.com/redirect.mp3/media.blubrry.com/transistor/cdn-transistor.prx.org/wp-content/uploads/Smithsonian3_Transistor.mp3"},
        {"Mode" => "HTTP", "URL" => "https://cdn-transistor.prx.org/shake.jpg"}
      ])

    importer.reload
    _(f.image.status).must_equal "created"
    _(f.contents.map(&:status)).must_equal ["created"]
  end

  it "creates correctly for libsyn entries" do
    e = libsyn_episode_import
    e.import!
    e.reload
    assert e.valid?
  end

  it "creates audio entries" do
    ei = EpisodeRssImport.create!(
      podcast_import: importer,
      entry: entry.to_h,
      guid: "https://transistor.prx.org/?p=1286"
    )

    _(ei.audio["files"].present?).must_equal(false)

    ei.import!

    _(ei.audio["files"].present?).must_equal(true)
  end

  it "sets an error status" do
    ei = EpisodeRssImport.create!(
      podcast_import: importer,
      entry: entry.to_h,
      guid: "https://transistor.prx.org/?p=1286"
    )

    ei.stub(:set_audio_metadata!, -> { raise "boom" }) do
      assert_raises(RuntimeError) { ei.import! }
    end

    _(ei.status).must_equal "error"
  end

  describe "helper methods" do
    let(:sample_link1) do
      "https://www.podtrac.com/pts/redirect.mp3/audio.wnyc.org/" \
        "radiolab_podcast/radiolab_podcast17updatecrispr.mp3"
    end
    let(:sample_link2) do
      "http://www.podtrac.com/pts/redirect.mp3/media.blubrry.com" \
        "/99percentinvisible/dovetail.prxu.org/99pi/9350e921-b910" \
        "-4b1c-bbc6-2912d79d014f/248-Atom-in-the-Garden-of-Eden.mp3"
    end
    let(:sample_link3) do
      "http://media.blubrry.com/some_name/www.podtrac.com/pts/redirect.mp3/blah"
    end

    it "can substitute for a missing short description" do
      e = entry.to_h.with_indifferent_access
      _(episode_import.episode_short_desc(e)).must_equal "An astronomer has turned the night sky into a symphony."

      e[:itunes_subtitle] = ""
      _(episode_import.episode_short_desc(e)).wont_equal ""

      e[:itunes_subtitle] = nil
      _(episode_import.episode_short_desc(e)).must_equal "Sidedoor from the Smithsonian: Shake it Up"

      e[:description] = "Some text that's under 50 words"
      _(episode_import.episode_short_desc(e)).must_equal "Some text that's under 50 words"
    end

    it "can substitute for a missing description" do
      entry.description = nil
      entry.itunes_summary = nil
      entry.content = nil
      _(episode_import.entry_description(entry.to_h.with_indifferent_access)).wont_be :blank?
    end

    it "can remove feedburner tracking pixels" do
      desc = 'desc <img src="http://feeds.feedburner.com/~r/transistor_stem/~4/NHnLCsjtdQM" ' \
        'height="1" width="1" alt=""/>'
      _(episode_import.remove_feedburner_tracker(desc)).must_equal "desc"
    end

    it "can remove unsafe tags" do
      desc = 'desc <iframe src="/"></iframe><script src="/"></script>'
      _(episode_import.sanitize_html(desc)).must_equal "desc"
    end

    it "can interpret explicit values" do
      %w[Yes TRUE Explicit].each { |x| _(episode_import.explicit(x)).must_equal "true" }
      %w[NO False Clean].each { |x| _(episode_import.explicit(x)).must_equal "false" }
      %w[UnClean y N 1 0].each { |x| _(episode_import.explicit(x)).must_be_nil }
    end
  end
end

def stub_requests
  stub_request(:get, "http://feeds.prx.org/transistor_stem")
    .to_return(status: 200, body: test_file("/fixtures/transistor_two.xml"), headers: {})
end
