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
    stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/7c8e5a1b-9d21-4f6c-b830-e42a87c3f9d2")
      .to_return(status: 200, body: test_file("/fixtures/megaphone_podcast.json"), headers: {})
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
    _(p.explicit).must_equal "false"
    _(p.owner_name).must_equal "PRX"
    _(p.owner_email).must_equal "help@prx.org"
    _(p.display_episodes_count).must_equal 5000
    _(p.itunes_type).must_equal "episodic"
  end
end
