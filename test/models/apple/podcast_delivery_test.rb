# frozen_string_literal: true

require "test_helper"

class Apple::PodcastDeliveryTest < ActiveSupport::TestCase
  describe ".create_logs" do
    let(:podcast) { create(:podcast) }
    let(:feed) { create(:feed, podcast: podcast, private: false) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:apple_show) { Apple::Show.new(feed) }
    let(:apple_episode) { Apple::Episode.new(apple_show, episode) }

    it "should create logs based on a returned row value" do
      podcast_container = Apple::PodcastContainer.create!

      assert_equal SyncLog.count, 0

      Apple::PodcastDelivery.create_logs(apple_episode, api_response: { val: { data: { id: "123" } } })

      assert_equal SyncLog.count, 1
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

  # test "the truth" do
  #   assert true
  # end
end
