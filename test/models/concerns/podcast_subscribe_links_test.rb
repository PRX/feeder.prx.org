require "test_helper"

class PodcastSubscribeLinksTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:podcast_2) { create(:podcast) }
  let(:apple_link) { SubscribeLink.create(platform: "apple", podcast: podcast, external_id: "12345") }

  before do
    assert apple_link
  end

  describe ".build_subscribe_links_json" do
    it "builds a json only if links are present" do
      refute_nil podcast.build_subscribe_links_json
      assert_nil podcast_2.build_subscribe_links_json
    end
  end

  describe ".copy_subscribe_links" do
    it "saves only if links are present" do
      refute_nil podcast.copy_subscribe_links
      assert_nil podcast_2.copy_subscribe_links
    end
  end
end
