require "test_helper"
require "ostruct"

describe PodcastRssImport do
  let(:user) { create(:user) }
  let(:podcast_url) { "http://feeds.prx.org/transistor_stem" }
  let(:podcast) { create(:podcast) }
  let(:importer) { PodcastRssImport.create(podcast: podcast, url: podcast_url) }
  let(:sns) { SnsMock.new }

  around do |test|
    sns.reset
    prev_sns = ENV["PORTER_SNS_TOPIC"]
    ENV["PORTER_SNS_TOPIC"] = "FOO"
    Task.stub :porter_sns_client, sns do
      test.call
    end
    ENV["PORTER_SNS_TOPIC"] = prev_sns
  end

  before do
    stub_requests
  end

  let(:feed) { Feedjira.parse(test_file("/fixtures/transistor_two.xml")) }

  it "retrieves a valid feed" do
    importer.feed
    _(importer.feed).wont_be_nil
    _(importer.feed_rss).wont_be_nil
    _(importer.config[:feed_rss]).wont_be_nil
  end

  it "retrieves a config" do
    importer.config_url = "http://test.prx.org/transistor_import_config.json"
    _(importer.config[:program]).must_equal "transistor_stem"
    _(importer.config[:audio]["https://transistor.prx.org/?p=1286"].count).must_equal 2
  end

  it "fails when feed is invalid" do
    importer.url = "https://www.prx.org/search/all.atom?q=radio"
    _ { importer.feed }.must_raise(RuntimeError)
  end

  it "updates a podcast" do
    importer.feed_rss = test_file("/fixtures/transistor_two.xml")
    importer.create_or_update_podcast!
    _(importer.podcast).wont_be_nil
    _(importer.podcast.account_id).wont_be_nil
    _(importer.podcast.title).must_equal "Transistor"
    _(importer.podcast.subtitle).must_equal "A podcast of scientific questions and " \
      "stories featuring guest hosts and reporters."
    _(importer.podcast.description).must_equal "Transistor is a podcast of scientific curiosities " \
      "and current events, featuring guest hosts, " \
      "scientists, and story-driven reporters. Presented " \
      "by radio and podcast powerhouse PRX, with support " \
      "from the Sloan Foundation."

    _(sns.messages.count).must_equal 2
    _(sns.messages.map { |m| m["Job"]["Tasks"].length }).must_equal [2, 2]
    _(sns.messages.map { |m| m["Job"]["Tasks"].map { |t| t["Type"] } }).must_equal [["Inspect", "Copy"], ["Inspect", "Copy"]]
    _(sns.messages.map { |m| m["Job"]["Source"] })
      .must_equal [
        {"Mode" => "HTTP", "URL" => "http://cdn-transistor.prx.org/transistor300.png"},
        {"Mode" => "HTTP", "URL" => "https://cdn-transistor.prx.org/transistor1400.jpg"}
      ]

    importer.reload
    _(importer.podcast.itunes_image.status).must_equal "created"
    _(importer.podcast.feed_image.status).must_equal "created"
  end

  it "creates podcast episode imports using a config" do
    importer.config_url = "http://test.prx.org/transistor_import_config.json"
    importer.import!

    eps = importer.episode_imports.reset
    eps.map(&:import!)
    importer = eps.first.podcast_import

    # get the memoized importer
    importer = importer.episode_imports.first.podcast_import
    _(importer.episode_imports.count).must_equal 2
  end

  it "imports a feed" do
    importer.import!
  end

  it "handles audio and video in episodes" do
    importer.url = "http://feeds.prx.org/feed_with_video"
    importer.import!

    eps = importer.episode_imports.reset.sort_by(&:guid)
    eps.map(&:import!)

    _(eps.length).must_equal 2

    _(eps[0].episode.contents.map(&:url).all? { |u| u =~ /\.mp4$/ }).must_equal true
    _(eps[1].episode.contents.map(&:url).all? { |u| u =~ /\.mp3$/ }).must_equal true
  end

  it "Sets a failed status with exceptions" do
    importer.stub(:feed_rss, -> { raise "foo" }) do
      assert_raises(RuntimeError) { importer.import! }
    end
    _(importer.status).must_equal "error"
  end

  describe "episodes only" do
    before {
      importer.config[:episodes_only] = true
    }

    it "must have podcast set" do
      importer.podcast = nil
      _ { importer.import! }.must_raise("No podcast for import of episodes only")
    end

    it "imports with a podcast" do
      importer.podcast = podcast
      importer.import!
    end
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

    it "can make a good guess for an enclosure prefix" do
      item = feed.entries.first
      _(importer.enclosure_prefix(item)).must_equal "https://dts.podtrac.com/redirect" \
        ".mp3/media.blubrry.com/transistor/"
      item.feedburner_orig_enclosure_link = nil
      item.enclosure.url = sample_link1
      _(importer.enclosure_prefix(item)).must_equal "https://www.podtrac.com/pts/redirect.mp3/"
      item.feedburner_orig_enclosure_link = "something_without_those_words"
      item.enclosure.url = sample_link2
      _(importer.enclosure_prefix(item)).must_equal "http://www.podtrac.com/pts/redirect" \
        ".mp3/media.blubrry.com/99percentinvisible/"
      item.feedburner_orig_enclosure_link = sample_link3
      _(importer.enclosure_prefix(item)).must_equal "http://www.podtrac.com/pts/redirect.mp3" \
        "/media.blubrry.com/some_name/"
    end

    it "can substitute for a missing short description" do
      _(importer.podcast_short_desc(feed)).must_equal "A podcast of scientific questions and stories" \
        " featuring guest hosts and reporters."
      feed.itunes_subtitle = nil
      _(importer.podcast_short_desc(feed)).must_equal "A podcast of scientific questions and stories," \
        " with many episodes hosted by key scientists" \
        " at the forefront of discovery."
      feed.description = nil
      _(importer.podcast_short_desc(feed)).must_equal "Transistor"
    end

    it "can remove feedburner tracking pixels" do
      desc = 'desc <img src="http://feeds.feedburner.com/~r/transistor_stem/~4/NHnLCsjtdQM" ' \
        'height="1" width="1" alt=""/>'
      _(importer.remove_feedburner_tracker(desc)).must_equal "desc"
    end

    it "can remove unsafe tags" do
      desc = 'desc <iframe src="/"></iframe><script src="/"></script>'
      _(importer.sanitize_html(desc)).must_equal "desc"
    end

    it "can interpret explicit values" do
      %w[Yes TRUE Explicit].each { |x| _(importer.explicit(x)).must_equal "true" }
      %w[NO False Clean].each { |x| _(importer.explicit(x)).must_equal "false" }
      %w[UnClean y N 1 0].each { |x| _(importer.explicit(x, "false")).must_equal "false" }
    end
  end

  describe("#episode_imports") do
    it("should create episode import placeholders") do
      importer.url = "http://feeds.prx.org/transistor_stem_duped"
      importer.import!
      _(importer.episode_imports.having_duplicate_guids.count).must_equal 3
      _(importer.episode_imports.non_duplicates.count).must_equal 3
    end

    it("should delete all import placeholders with each import") do
      importer.url = "http://feeds.prx.org/transistor_stem_duped"
      importer.import!
      # invoke the creation of placeholders
      importer.create_or_update_episode_imports!
      _(importer.episode_imports.having_duplicate_guids.count).must_equal 3
    end
  end

  describe("#parse_feed_entries_for_dupe_guids") do
    it "will parse feed entries for good and duped entries" do
      importer.feed_rss = test_file("/fixtures/transistor_dupped_guids.xml")
      good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
      _(good_entries.length).must_equal 3
      _(dupped_guid_entries.length).must_equal 3
    end

    it "handles entry lists of size 0" do
      importer.stub(:feed, []) do
        good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
        _(good_entries.length).must_equal 0
        _(dupped_guid_entries.length).must_equal 0
      end
    end

    it "handles entry lists of size 1" do
      importer.stub(:feed, [OpenStruct.new(entry_id: 1)]) do
        good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
        _(good_entries.length).must_equal 1
        _(dupped_guid_entries.length).must_equal 0
      end
    end
  end

  describe("#feed_episode_count") do
    it "registers the count of episodes in the feed" do
      importer.import!
      _(importer.feed_episode_count).must_equal 2
      _(importer.episode_imports.count).must_equal 2

      _(importer.podcast.episodes.count).must_equal 0
    end
  end
end

def stub_requests
  stub_request(:get, "http://feeds.prx.org/transistor_stem")
    .to_return(status: 200, body: test_file("/fixtures/transistor_two.xml"), headers: {})

  stub_request(:get, "http://test.prx.org/transistor_import_config.json")
    .to_return(status: 200, body: json_file("transistor_import_config"), headers: {})

  stub_request(:get, "https://www.prx.org/search/all.atom?q=radio")
    .to_return(status: 200, body: test_file("/fixtures/prx-atom.xml"), headers: {})

  stub_request(:get, "http://feeds.prx.org/transistor_stem_duped")
    .to_return(status: 200, body: test_file("/fixtures/transistor_dupped_guids.xml"), headers: {})

  stub_request(:get, "http://feeds.prx.org/feed_with_video")
    .to_return(status: 200, body: test_file("/fixtures/99pi-feed-rss.xml"), headers: {})
end
