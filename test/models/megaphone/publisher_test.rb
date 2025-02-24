require "test_helper"

describe Megaphone::Publisher do
  let(:podcast) { create(:podcast, id: 1234) }
  let(:public_feed) { podcast.default_feed }
  let(:feed) { create(:megaphone_feed, podcast: podcast, private: true) }

  let(:publisher) do
    Megaphone::Publisher.new(feed)
  end

  describe ".initialize" do
    it "should build a publisher with the correct feeds" do
      assert_equal publisher.feed, feed
      assert_equal publisher.podcast, podcast
      assert_equal publisher.public_feed, public_feed
    end
  end

  describe "sync_episodes!" do
    let(:episode) { create(:episode, podcast: podcast) }

    before do
      # setup the megaphone podcast
      stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/A1B2C4D5E6F7G8")
        .to_return(status: 200, body: {id: "A1B2C4D5E6F7G8", updatedAt: (Time.now + 1.minute).utc.iso8601}.to_json, headers: {})

      SyncLog.log!(
        integration: :megaphone,
        feeder_id: public_feed.id,
        feeder_type: :feeds,
        external_id: "A1B2C4D5E6F7G8",
        api_response: {request: {}, items: {}}
      )

      # setup augury placements for the podcast
      stub_request(:post, "https://#{ENV["ID_HOST"]}/token")
        .to_return(status: 200,
          body: '{"access_token":"thisisnotatoken","token_type":"bearer"}',
          headers: {"Content-Type" => "application/json; charset=utf-8"})

      stub_request(:get, "https://#{ENV["AUGURY_HOST"]}/api/v1/podcasts/#{podcast.id}/placements")
        .to_return(status: 200, body: json_file(:placements), headers: {})

      stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/A1B2C4D5E6F7G8/episodes?externalId=#{episode.guid}")
        .to_return(status: 200, body: [].to_json, headers: {})

      stub_request(:post, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/A1B2C4D5E6F7G8/episodes")
        .to_return(status: 200, body: {id: "megaphone-episode-guid"}.to_json, headers: {})
    end

    it "should create new draft episodes" do
      assert episode
      publisher.sync_episodes!
    end

    it "should update episodes" do
    end

    it "should update episodes with audio" do
    end

    it "should update episodes with incomplete audio" do
    end
  end

  describe "#sync_podcast!" do
    it "should create a new podcast" do
      stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts?externalId=95ebfb22-0002-5f78-a7aa-5acb5ac7daa9")
        .to_return(status: 200, body: [].to_json, headers: {})

      stub_request(:post, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts")
        .to_return(status: 200, body: {id: "ABC12345"}.to_json, headers: {})

      megaphone_podcast = publisher.sync_podcast!
      assert_not_nil megaphone_podcast
      assert_equal megaphone_podcast.id, "ABC12345"
    end

    it "should find a podcast by megaphone id" do
      stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/A1B2C4D5E6F7G8")
        .to_return(status: 200, body: {id: "A1B2C4D5E6F7G8", updatedAt: (Time.now + 1.minute).utc.iso8601}.to_json, headers: {})

      SyncLog.log!(
        integration: :megaphone,
        feeder_id: public_feed.id,
        feeder_type: :feeds,
        external_id: "A1B2C4D5E6F7G8",
        api_response: {request: {}, items: {}}
      )

      megaphone_podcast = publisher.sync_podcast!
      assert_not_nil megaphone_podcast
      assert_equal megaphone_podcast.id, "A1B2C4D5E6F7G8"
    end

    it "should find and update a podcast by guid" do
      stub_request(:get, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts?externalId=95ebfb22-0002-5f78-a7aa-5acb5ac7daa9")
        .to_return(status: 200, body: [{id: "DEF67890", updatedAt: "2024-11-03T14:54:02.690Z"}].to_json, headers: {})

      stub_request(:put, "https://cms.megaphone.fm/api/networks/this-is-a-network-id/podcasts/DEF67890")
        .to_return(status: 200, body: [{id: "DEF67890", updatedAt: Time.now.utc.iso8601}].to_json, headers: {})

      megaphone_podcast = publisher.sync_podcast!
      assert_not_nil megaphone_podcast
      assert_equal megaphone_podcast.id, "DEF67890"
    end
  end
end
