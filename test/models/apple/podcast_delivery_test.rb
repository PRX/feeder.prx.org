# frozen_string_literal: true

require "test_helper"

class Apple::PodcastDeliveryTest < ActiveSupport::TestCase
  describe ".upsert_podcast_delivery" do
    let(:podcast) { create(:podcast) }
    let(:feed) { create(:feed, podcast: podcast, private: false) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:apple_show) { Apple::Show.new(feed) }
    let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

    let(:podcast_delivery_json) { { val: { data: { id: "123" } } } }

    it "should create logs based on a returned row value" do
      assert_equal SyncLog.count, 0
      assert_equal Apple::PodcastDelivery.count, 0

      Apple::PodcastDelivery.upsert_podcast_delivery(apple_episode,
                                                     api_response: podcast_delivery_json)

      assert_equal SyncLog.count, 1
      assert_equal Apple::PodcastDelivery.count, 1

      # Now upsert existing record
      Apple::PodcastDelivery.upsert_podcast_delivery(apple_episode,
                                                     api_response: podcast_delivery_json)

      assert_equal SyncLog.count, 2
      assert_equal Apple::PodcastDelivery.count, 1
    end

    it "should update timestamps" do
      pd = Apple::PodcastDelivery.upsert_podcast_delivery(apple_episode,
                                                          api_response: podcast_delivery_json)

      # Now upsert existing record and overwrite timestamps
      pd.update(updated_at: Time.now - 1.year)
      pd2 = Apple::PodcastDelivery.upsert_podcast_delivery(apple_episode,
                                                           api_response: podcast_delivery_json)
      assert pd2.updated_at > pd.updated_at
    end
  end

  describe "#podcast_delivery" do
    let(:container) { Apple::PodcastContainer.new }
    it "should have one delivery" do
      assert_nil container.podcast_delivery
      container.build_podcast_delivery
      assert_equal container.podcast_delivery.class, Apple::PodcastDelivery
    end
  end
end
