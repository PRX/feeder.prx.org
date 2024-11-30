require "test_helper"

describe Megaphone::Publisher do
  let(:podcast) { create(:podcast) }
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

    it "should find a podcast by guid" do
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
