require "test_helper"

describe PodcastMegaphoneImport do
  let(:default_feed) { create(:default_feed, audio_format: nil) }
  let(:podcast) { create(:podcast, default_feed: default_feed) }
  let(:megaphone_feed) { create(:megaphone_feed, podcast: podcast) }

  let(:importer) { PodcastMegaphoneImport.create(podcast: podcast, megaphone_podcast_id: "7c8e5a1b-9d21-4f6c-b830-e42a87c3f9d2") }
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

  it "retrieves podcast from megaphone" do
    importer.megaphone_feed = megaphone_feed
    mp = importer.find_megaphone_podcast
    _(mp).wont_be_nil
    _(mp.id).must_equal "7c8e5a1b-9d21-4f6c-b830-e42a87c3f9d2"
  end

  it "create_or_update_podcast!" do
    importer.megaphone_feed = megaphone_feed
    p = importer.create_or_update_podcast!
    _(p).wont_be_nil
    _(p.account_id).wont_be_nil
    _(p.title).must_equal "PRX Expounds..."
    _(p.subtitle).must_equal "Things are happening fast and sometimes you need to take a step back."
    _(p.description).must_equal "<p>Things are happening fast and sometimes you need to take a step back to truly understand the way the world is changing. PRX Expounds dives deep with multi-part series on the biggest news stories of the day to provide you with the context and analysis you need.</p>"
    _(p.itunes_categories.map(&:name)).must_equal ["News"]
    _(p.language).must_equal "en-us"
    _(p.link).must_equal "https://www.prx.org/expounds"
    _(p.copyright).must_equal "Copyright 2023 PRX"
    _(p.author_name).must_equal "PRX"
    _(p.explicit).must_equal false
    _(p.owner_name).must_equal "PRX"
    _(p.owner_email).must_equal "help@prx.org"
    _(p.display_episodes_count).must_equal 5000
    _(p.itunes_type).must_equal "episodic"
  end

#   it "updates a podcast" do
#     importer.create_or_update_podcast!
#     _(importer.podcast).wont_be_nil
#     _(importer.podcast.account_id).wont_be_nil
#     _(importer.podcast.title).must_equal "Transistor"
#     _(importer.podcast.subtitle).must_equal "A podcast of scientific questions and " \
#       "stories featuring guest hosts and reporters."
#     _(importer.podcast.description).must_equal "A podcast of scientific questions and stories," \
#         " with many episodes hosted by key scientists" \
#         " at the forefront of discovery."

#     _(importer.podcast.url).must_equal "http://feeds.prx.org/transistor_stem"
#     _(importer.podcast.new_feed_url).must_equal "http://feeds.prx.org/transistor_stem"

#     _(importer.podcast.author_name).must_equal "PRX"
#     _(importer.podcast.author_email).must_be_nil
#     _(importer.podcast.owner_name).must_equal "PRX"
#     _(importer.podcast.owner_email).must_equal "prxwpadmin@prx.org"
#     _(importer.podcast.managing_editor_name).must_equal "PRX"
#     _(importer.podcast.managing_editor_email).must_equal "prxwpadmin@prx.org"

#     # lock for some minutes, but not forever (in case there are 0 episodes)
#     _(importer.podcast.locked).must_equal true
#     _(importer.podcast.locked_until).must_be :>, 5.minutes.from_now
#     _(importer.podcast.locked_until).must_be :<, 30.minutes.from_now

#     # categories, itunes:keywords and media:keywords are combined
#     _(importer.podcast.categories).must_equal ["Some Category", "keyword1", "keyword two", "media one"]

#     _(sns.messages.count).must_equal 2
#     _(sns.messages.map { |m| m["Job"]["Tasks"].length }).must_equal [2, 2]
#     _(sns.messages.map { |m| m["Job"]["Tasks"].map { |t| t["Type"] } }).must_equal [["Inspect", "Copy"], ["Inspect", "Copy"]]
#     _(sns.messages.map { |m| m["Job"]["Source"] })
#       .must_equal [
#         {"Mode" => "HTTP", "URL" => "http://cdn-transistor.prx.org/transistor300.png"},
#         {"Mode" => "HTTP", "URL" => "https://cdn-transistor.prx.org/transistor1400.jpg"}
#       ]

#     importer.reload
#     _(importer.podcast.itunes_image.status).must_equal "created"
#     _(importer.podcast.feed_image.status).must_equal "created"
#   end

#   describe "episodes only" do
#     before {
#       importer.config[:episodes_only] = true
#     }

#     it "must have podcast set" do
#       importer.podcast = nil
#       _ { importer.import! }.must_raise("No podcast for import of episodes only")
#     end
#   end

#   describe "helper methods" do
#     let(:sample_link1) do
#       "https://www.podtrac.com/pts/redirect.mp3/audio.wnyc.org/" \
#         "radiolab_podcast/radiolab_podcast17updatecrispr.mp3"
#     end
#     let(:sample_link2) do
#       "http://www.podtrac.com/pts/redirect.mp3/media.blubrry.com" \
#         "/99percentinvisible/dovetail.prxu.org/99pi/9350e921-b910" \
#         "-4b1c-bbc6-2912d79d014f/248-Atom-in-the-Garden-of-Eden.mp3"
#     end
#     let(:sample_link3) do
#       "https://pts.podtrac.com/redirect.mp3/pdst.fm/e/chtbl.com/track/7E7E1F/blah"
#     end

#     it "looks for an owner" do
#       one = "<itunes:name>one</itunes:name><itunes:email>one@one.one</itunes:email>"
#       two = "<itunes:name>two</itunes:name><itunes:email>two@two.two</itunes:email>"
#       owner1 = "<itunes:owner>#{one}</itunes:owner>"
#       owner2 = "<itunes:owner>#{two}</itunes:owner>"

#       importer.feed_rss = "<rss></rss>"
#       _(importer.owner).must_equal({})

#       importer.feed_rss = "<rss><itunes:owner></itunes:owner></rss>"
#       _(importer.owner).must_equal({name: nil, email: nil}.with_indifferent_access)

#       importer.feed_rss = "<rss>#{owner1}#{owner2}</rss>"
#       _(importer.owner).must_equal({name: "one", email: "one@one.one"}.with_indifferent_access)
#     end

#     it "can make a good guess for an enclosure prefix" do
#       _(importer.enclosure_prefix).must_equal "https://dts.podtrac.com/redirect.mp3/media.blubrry.com/transistor/"

#       importer.first_entry[:feedburner_orig_enclosure_link] = nil
#       importer.first_entry[:enclosure][:url] = sample_link1
#       _(importer.enclosure_prefix).must_equal "https://www.podtrac.com/pts/redirect.mp3/"

#       importer.first_entry[:feedburner_orig_enclosure_link] = "something_without_those_words"
#       importer.first_entry[:enclosure][:url] = sample_link2
#       _(importer.enclosure_prefix).must_equal "http://www.podtrac.com/pts/redirect.mp3/media.blubrry.com/99percentinvisible/"

#       importer.first_entry[:feedburner_orig_enclosure_link] = sample_link3
#       _(importer.enclosure_prefix).must_equal "https://pts.podtrac.com/redirect.mp3/pdst.fm/e/chtbl.com/track/7E7E1F/"
#     end

#     it "can substitute for a missing short description" do
#       _(importer.podcast_short_desc).must_equal "A podcast of scientific questions and stories" \
#         " featuring guest hosts and reporters."

#       importer.channel[:itunes_subtitle] = nil
#       _(importer.podcast_short_desc).must_equal "A podcast of scientific questions and stories," \
#         " with many episodes hosted by key scientists" \
#         " at the forefront of discovery."

#       importer.channel[:description] = nil
#       _(importer.podcast_short_desc).must_equal "Transistor"
#     end

#     it "can remove feedburner tracking pixels" do
#       desc = 'desc <img src="http://feeds.feedburner.com/~r/transistor_stem/~4/NHnLCsjtdQM" ' \
#         'height="1" width="1" alt=""/>'
#       _(importer.remove_feedburner_tracker(desc)).must_equal "desc"
#     end

#     it "can remove podcastchoices links" do
#       desc = "Plain text. Learn more about your ad choices. Visit podcastchoices.com/adchoices. More stuff."
#       _(importer.remove_podcastchoices_link(desc)).must_equal "Plain text.  More stuff."

#       desc = "<p>Hello</p><p>Learn more about your ad choices. Visit <a href=\"https://podcastchoices.com/adchoices\">podcastchoices.com/adchoices</a></p><p>Extra stuff</p>"
#       _(importer.remove_podcastchoices_link(desc)).must_equal "<p>Hello</p><p>Extra stuff</p>"
#     end

#     it "can remove unsafe tags" do
#       desc = 'desc <iframe src="/"></iframe><script src="/"></script>'
#       _(importer.sanitize_html(desc)).must_equal "desc"
#     end

#     it "can interpret explicit values" do
#       %w[Yes TRUE Explicit].each { |x| _(importer.explicit(x)).must_equal "true" }
#       %w[NO False Clean].each { |x| _(importer.explicit(x)).must_equal "false" }
#       %w[UnClean y N 1 0].each { |x| _(importer.explicit(x, "false")).must_equal "false" }
#     end
#   end

#   describe("#episode_imports") do
#     it("should create episode import placeholders") do
#       importer.url = "http://feeds.prx.org/transistor_stem_duped"
#       importer.import!
#       _(importer.episode_imports.status_duplicate.count).must_equal 2
#       _(importer.episode_imports.not_status_duplicate.count).must_equal 4
#     end

#     it("should delete all import placeholders with each import") do
#       importer.url = "http://feeds.prx.org/transistor_stem_duped"
#       importer.import!
#       # invoke the creation of placeholders
#       importer.create_or_update_episode_imports!
#       _(importer.episode_imports.status_duplicate.count).must_equal 2
#     end
#   end

#   describe("#feed_episode_count") do
#     it "registers the count of episodes in the feed" do
#       importer.import!
#       _(importer.feed_episode_count).must_equal 2
#       _(importer.episode_imports.count).must_equal 2

#       _(importer.podcast.episodes.count).must_equal 0
#     end
#   end
end

def stub_requests
  stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/7c8e5a1b-9d21-4f6c-b830-e42a87c3f9d2").
    to_return(status: 200, body: test_file("/fixtures/megaphone_podcast.json"), headers: {})
end
