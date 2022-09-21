# frozen_string_literal: true

require "test_helper"

class Apple::PodcastContainerTest < ActiveSupport::TestCase
  describe ".create_podcast_containers" do
    let(:podcast) { create(:podcast) }
    let(:feed) { create(:feed, podcast: podcast, private: false) }
    let(:episode) { create(:episode, podcast: podcast) }
    let(:apple_show) { Apple::Show.new(feed) }
    let(:apple_episode) { Apple::Episode.new(apple_show, episode) }

    it "should create logs based on a returned row value" do
      assert_equal SyncLog.count, 0

      apple_episode.stub(:apple_id, "1234") do
        apple_episode.stub(:audio_asset_vendor_id, "5678") do
          Apple::PodcastContainer.create_podcast_container(apple_episode, api_response: { val: { data: { id: "123" } } })
        end
      end

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
