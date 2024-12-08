require "test_helper"

describe Megaphone::Episode do
  let(:feeder_podcast) { create(:podcast) }
  let(:feed) { create(:megaphone_feed, podcast: feeder_podcast) }
  let(:feeder_episode) { create(:episode, podcast: feeder_podcast, segment_count: 2) }
  let(:podcast) { Megaphone::Podcast.new_from_feed(feed) }

  describe "#valid?" do
    before {
      stub_request(:post, "https://#{ENV["ID_HOST"]}/token")
        .to_return(status: 200,
          body: '{"access_token":"thisisnotatoken","token_type":"bearer"}',
          headers: {"Content-Type" => "application/json; charset=utf-8"})

      stub_request(:get, "https://#{ENV["AUGURY_HOST"]}/api/v1/podcasts/#{feeder_podcast.id}/placements")
        .to_return(status: 200, body: json_file(:placements), headers: {})
    }
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

  describe "#create!" do
    it "can create a draft with no audio" do
    end
    it "can create a published episodes with audio" do
    end
    it "can create a published episodes with the wrong media vetsion from DTR" do
    end
  end
end
