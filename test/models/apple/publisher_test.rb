# frozen_string_literal: true

require "test_helper"

describe Apple::Publisher do
  let(:podcast) { create(:podcast) }
  let(:public_feed) { create(:feed, podcast: podcast, private: false) }
  let(:private_feed) { create(:feed, podcast: podcast, private: true) }
  let(:apple_creds) { build(:apple_credential) }
  let(:apple_api) { Apple::Api.from_apple_credentials(apple_creds) }

  let(:apple_publisher) do
    Apple::Publisher.new(api: apple_api, public_feed: public_feed, private_feed: private_feed)
  end

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200").
      to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})

    public_feed.exclude_tags = [Episode::APPLE_FREEMIUM_TAG, Episode::APPLE_ONLY_TAG]
    public_feed.save!
  end

  describe ".initialize" do
    it "should build a publisher with the correct feeds" do
      assert_equal apple_publisher.public_feed, public_feed
      assert_equal apple_publisher.private_feed, private_feed
    end
  end

  describe "#episodes_to_sync" do
    let(:episode) { create(:episode, podcast: podcast) }

    before do
      episode.categories = [Episode::APPLE_FREEMIUM_TAG]
      episode.save!
    end

    it "should return the episodes to sync" do
      assert_equal apple_publisher.episodes_to_sync.map(&:feeder_id), [episode.id]

      # derived from the underlying feeds
      assert_equal public_feed.filtered_episodes.map(&:id), []
      assert_equal private_feed.filtered_episodes.map(&:id), [episode.id]
    end
  end
end
