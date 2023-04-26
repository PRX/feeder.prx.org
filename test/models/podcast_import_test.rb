require "test_helper"
require "prx_access"
require "ostruct"

describe PodcastImport do
  let(:user) { create(:user) }
  let(:account_id) { user.authorized_account_ids(:podcast_edit).first }
  let(:podcast_url) { "http://feeds.prx.org/transistor_stem" }
  let(:podcast) { create(:podcast) }
  let(:importer) { PodcastImport.create(podcast: podcast, account_id: account_id, url: podcast_url) }
  let(:sns) { SnsMock.new }

  around do |test|
    sns.reset
    prev_sns = ENV["PORTER_SNS_TOPIC"]
    ENV["PORTER_SNS_TOPIC"] = "FOO"
    Task.stub :new_porter_sns_client, sns do
      test.call
    end
    ENV["PORTER_SNS_TOPIC"] = prev_sns
  end

  before do
    stub_requests
  end

  let(:feed) { Feedjira::Feed.parse(test_file("/fixtures/transistor_two.xml")) }

  it "retrieves a valid feed" do
    importer.get_feed
    _(importer.feed).wont_be_nil
  end

  it "retrieves a config" do
    importer.config_url = "http://test.prx.org/transistor_import_config.json"
    _(importer.config[:program]).must_equal "transistor_stem"
    _(importer.config[:audio]["https://transistor.prx.org/?p=1286"].count).must_equal 2
  end

  it "fails when feed is invalid" do
    importer.url = "https://www.prx.org/search/all.atom?q=radio"
    _ { importer.get_feed }.must_raise(RuntimeError)
  end

  it "updates a podcast" do
    importer.feed = feed
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
    _(sns.messages.map { |m| m["Job"]["Tasks"].length }).must_equal [1, 1]
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
    importer.import

    eps = importer.episode_imports.reset
    eps.map(&:import)
    importer = eps.first.podcast_import

    # get the memoized importer
    importer = importer.episode_imports.first.podcast_import
    _(importer.episode_imports.count).must_equal 2
  end

  it "imports a feed" do
    importer.import
  end

  it "handles audio and video in episodes" do
    importer.url = "http://feeds.prx.org/feed_with_video"
    importer.import

    eps = importer.episode_imports.reset
    eps.map(&:import)

    _(eps.length).must_equal 2

    _(eps[0].episode.contents.map(&:url).all? { |u| u =~ /\.mp4$/ }).must_equal true
    _(eps[1].episode.contents.map(&:url).all? { |u| u =~ /\.mp3$/ }).must_equal true
  end

  describe "episodes only" do
    before {
      importer.config[:episodes_only] = true
    }

    it "must have podcast set" do
      importer.podcast = nil
      _ { importer.import }.must_raise("No podcast for import of episodes only")
    end

    it "imports with a podcast" do
      importer.podcast = podcast
      importer.import
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
      importer.import
      _(importer.episode_imports.having_duplicate_guids.count).must_equal 3
      _(importer.episode_imports.count).must_equal 3
    end

    it("should delete all import placeholders with each import") do
      importer.url = "http://feeds.prx.org/transistor_stem_duped"
      importer.import_podcast!
      # invoke the creation of placeholders
      importer.import_episodes!
      importer.create_or_update_episode_imports!
      _(importer.episode_imports.having_duplicate_guids.count).must_equal 3
    end
  end

  describe("#parse_feed_entries_for_dupe_guids") do
    let(:rss_feed) { Feedjira::Feed.parse(test_file("/fixtures/transistor_dupped_guids.xml")) }

    it "will parse feed entries for good and duped entries" do
      importer.feed = rss_feed
      good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
      _(good_entries.length).must_equal 3
      _(dupped_guid_entries.length).must_equal 3
    end

    it "handles entry lists of size 0" do
      importer.feed = []
      good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
      _(good_entries.length).must_equal 0
      _(dupped_guid_entries.length).must_equal 0
    end

    it "handles entry lists of size 1" do
      importer.feed = [OpenStruct.new(entry_id: 1)]
      good_entries, dupped_guid_entries = importer.parse_feed_entries_for_dupe_guids
      _(good_entries.length).must_equal 1
      _(dupped_guid_entries.length).must_equal 0
    end
  end

  describe("#feed_episode_count") do
    it "registers the count of episodes in the feed" do
      importer.import
      _(importer.feed_episode_count).must_equal 2
      _(importer.episode_imports.count).must_equal 2

      _(importer.podcast.episodes.count).must_equal 0
    end
  end

  describe("#status") do
    it "sets a status based on the episode imports" do
      importer.import
      _(importer.status).must_equal PodcastImport::IMPORTING

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      _(importer.status).must_equal PodcastImport::IMPORTING

      ep1.update! status: EpisodeImport::COMPLETE
      ep2.update! status: EpisodeImport::COMPLETE

      importer.reload

      _(importer.complete?).must_equal true
      _(importer.finished?).must_equal true
      _(importer.some_failed?).must_equal false
      _(importer.status).must_equal PodcastImport::COMPLETE
    end

    it "is failed so long as the import is finished" do
      importer.import
      _(importer.status).must_equal PodcastImport::IMPORTING

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      ep1.update! status: EpisodeImport::FAILED
      ep2.update! status: EpisodeImport::COMPLETE

      importer.reload

      _(importer.complete?).must_equal false
      _(importer.finished?).must_equal true
      _(importer.some_failed?).must_equal true
      _(importer.status).must_equal PodcastImport::FAILED
    end

    it "is in progress so long as the episode imports are not all created" do
      importer.import

      # simulate a more imports than currently created
      importer.update(feed_episode_count: 3)
      _(importer.episode_imports.length).must_equal 2

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      ep1.update! status: EpisodeImport::FAILED
      ep2.update! status: EpisodeImport::FAILED

      importer.reload

      _(importer.complete?).must_equal false
      _(importer.finished?).must_equal false
      _(importer.some_failed?).must_equal true
      _(importer.status).must_equal PodcastImport::IMPORTING
    end

    it "is in progress so long as the episode imports are not finished" do
      importer.import

      # simulate a more imports than currently created
      _(importer.episode_imports.length).must_equal 2

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      ep1.update! status: EpisodeImport::FAILED
      ep2.update! status: EpisodeImport::EPISODE_SAVED

      importer.reload

      _(importer.complete?).must_equal false
      _(importer.finished?).must_equal false
      _(importer.some_failed?).must_equal true
      _(importer.status).must_equal PodcastImport::IMPORTING
    end

    it "should unlock the podcast distribution once all the episodes are imported" do
      importer.import

      ep1 = importer.episode_imports[0]
      ep2 = importer.episode_imports[1]

      ep1.update! status: EpisodeImport::COMPLETE
      ep2.update! status: EpisodeImport::FAILED

      ep1.import
      _(importer.podcast.locked).must_equal false
    end
  end
end

def stub_requests
  stub_request(:put, "https://feeder.prx.org/api/v1/podcasts/51")
    .with(body: "{\"copyright\":\"Copyright 2016 PRX\",\"language\":\"en-US\",\"updateFrequency\":\"1\",\"updatePeriod\":\"hourly\",\"summary\":\"Transistor is a podcast of scientific curiosities and current events, featuring guest hosts, scientists, and story-driven reporters. Presented by radio and podcast powerhouse PRX, with support from the Sloan Foundation.\",\"link\":\"https://transistor.prx.org\",\"explicit\":\"false\",\"newFeedUrl\":\"http://feeds.prx.org/transistor_stem\",\"enclosurePrefix\":\"https://dts.podtrac.com/redirect.mp3/media.blubrry.com/transistor/\",\"feedburnerUrl\":\"http://feeds.feedburner.com/transistor_stem\",\"url\":\"http://feeds.feedburner.com/transistor_stem\",\"author\":{\"name\":\"PRX\",\"email\":null},\"managingEditor\":{\"name\":\"PRX\",\"email\":\"prxwpadmin@prx.org\"},\"owner\":{\"name\":\"PRX\",\"email\":\"prxwpadmin@prx.org\"},\"itunesCategories\":[{\"name\":\"Science\",\"subcategories\":[\"Natural Sciences\"]}],\"categories\":[],\"complete\":false,\"keywords\":[],\"serialOrder\":false,\"locked\":true}",
      headers: {"Accept" => "application/json", "Authorization" => "Bearer thisisnotatoken", "Content-Type" => "application/json", "Host" => "feeder.prx.org", "User-Agent" => "HyperResource 0.9.4"})
    .to_return(status: 200, body: "", headers: {})

  stub_request(:put, "https://feeder.prx.org/api/v1/podcasts/51")
    .with(body: "{\"locked\":false}",
      headers: {"Accept" => "application/json", "Authorization" => "Bearer thisisnotatoken", "Content-Type" => "application/json", "Host" => "feeder.prx.org", "User-Agent" => "HyperResource 0.9.4"})
    .to_return(status: 200, body: "", headers: {})

  stub_request(:get, "http://feeds.prx.org/transistor_stem")
    .to_return(status: 200, body: test_file("/fixtures/transistor_two.xml"), headers: {})

  stub_request(:get, "http://test.prx.org/transistor_import_config.json")
    .to_return(status: 200, body: json_file("transistor_import_config"), headers: {})

  stub_request(:get, "https://www.prx.org/search/all.atom?q=radio")
    .to_return(status: 200, body: test_file("/fixtures/prx-atom.xml"), headers: {})

  stub_request(:post, "https://id.prx.org/token")
    .to_return(status: 200,
      body: '{"access_token":"thisisnotatoken","token_type":"bearer"}',
      headers: {"Content-Type" => "application/json; charset=utf-8"})

  stub_request(:get, "https://feeder.prx.org/api/v1")
    .with(headers: {"Authorization" => "Bearer thisisnotatoken"})
    .to_return(status: 200, body: json_file("feeder_root"), headers: {})

  stub_request(:get, "https://feeder.prx.org/api/v1/podcasts/51")
    .with(headers: {"Authorization" => "Bearer thisisnotatoken"})
    .to_return(status: 200, body: json_file("transistor_podcast_basic"), headers: {})

  stub_request(:post, "https://feeder.prx.org/api/v1/podcasts")
    .with(body: /prxUri/)
    .to_return(status: 200, body: json_file("transistor_podcast_basic"), headers: {})

  stub_request(:post, "https://feeder.prx.org/api/v1/podcasts/51/episodes")
    .with(body: /prxUri/,
      headers: {"Authorization" => "Bearer thisisnotatoken"})
    .to_return(status: 200, body: json_file("transistor_episode"), headers: {})

  stub_request(:get, "https://feeder.prx.org/api/v1/authorization/episodes/153e6ea8-6485-4d53-9c22-bd996d0b3b03")
    .with(headers: {"Authorization" => "Bearer thisisnotatoken"})
    .to_return(status: 200, body: json_file("transistor_episode"), headers: {})

  stub_request(:get, "https://feeder.prx.org/api/v1/podcasts/23")
    .with(headers: {"Authorization" => "Bearer thisisnotatoken"})
    .to_return(status: 200, body: json_file("transistor_podcast_basic"), headers: {})

  stub_request(:get, "http://feeds.prx.org/transistor_stem_duped")
    .to_return(status: 200, body: test_file("/fixtures/transistor_dupped_guids.xml"), headers: {})

  stub_request(:get, "http://feeds.prx.org/feed_with_video")
    .to_return(status: 200, body: test_file("/fixtures/99pi-feed-rss.xml"), headers: {})

  stub_request(:get, "https://cdn-transistor.prx.org/transistor1400.jpg")
    .to_return(status: 200, body: test_file("/fixtures/transistor1400.jpg"), headers: {})

  stub_request(:get, "https://f.prxu.org/99pi/images/6a748676-76e8-45fd-8de2-a868a58f6b8b/99-1400.png")
    .to_return(status: 200, body: test_file("/fixtures/99-1400.png"), headers: {})

  stub_request(:get, "https://cdn-transistor.prx.org/shake.jpg")
    .to_return(status: 200, body: test_file("/fixtures/transistor1400.jpg"), headers: {})

  stub_request(:get, "http://cdn-transistor.prx.org/transistor300.png")
    .to_return(status: 200, body: test_file("/fixtures/transistor300.png"), headers: {})

  stub_request(:get, "https://f.prxu.org/99pi/images/42384e27-3dd6-497f-991f-67fabb7e6e5b/99-300.png")
    .to_return(status: 200, body: test_file("/fixtures/99-300.png"), headers: {})
end
