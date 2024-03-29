require "test_helper"
require "prx_access"

describe Podcast do
  include PrxAccess

  let(:podcast) { create(:podcast) }

  it "has episodes" do
    assert_respond_to podcast, :episodes
  end

  it "has a default feed" do
    podcast = Podcast.new.tap(&:valid?)
    assert podcast.default_feed.present?
    assert podcast.default_feed.private? == false
    assert podcast.default_feed.slug.nil?
    assert podcast.default_feed.file_name == Feed::DEFAULT_FILE_NAME
  end

  it "is episodic or serial" do
    assert_match(/episodic/, podcast.itunes_type)
    podcast.update(serial_order: true)
    assert_match(/serial/, podcast.itunes_type)
  end

  it "updates last build date after update" do
    Timecop.freeze
    podcast.update(managing_editor: "Brian Fernandez")

    assert_equal podcast.last_build_date, Time.now

    Timecop.return
  end

  it "wont nil out podcast published_at" do
    ep = podcast.episodes.create(title: "title", published_at: 1.week.ago)
    pub_at = podcast.reload.published_at
    refute_nil podcast.published_at

    ep.update(published_at: 1.week.from_now)
    podcast.reload
    refute_nil podcast.published_at
    refute_equal podcast.published_at, ep.published_at
    refute_equal podcast.published_at, pub_at

    ep.destroy
    refute_nil podcast.reload.published_at
  end

  it "sets the itunes block to false by default" do
    refute podcast.itunes_block
    podcast.update(itunes_block: true)
    assert podcast.itunes_block
  end

  it "gets and sets link" do
    p = build_stubbed(:podcast, link: nil)
    assert_includes p.link, "play.prx.org"
    assert_nil p[:link]

    p.link = "http://some.where/else"
    assert_equal "http://some.where/else", p[:link]

    p.link = "https://play.prx.org/any/thing"
    assert_nil p[:link]
  end

  describe "publishing" do
    it "creates a publish job on publish" do
      PublishingPipelineState.stub(:start_pipeline!, "published!") do
        assert_equal StartPublishingPipelineJob, podcast.publish!.class
      end
    end

    it "wont create a publish job when podcast is locked" do
      PublishingPipelineState.stub(:start_pipeline!, "published!") do
        podcast.locked = true
        refute_equal StartPublishingPipelineJob, podcast.publish!.class
      end
    end
  end

  describe "episode limit" do
    let(:episodes) { create_list(:episode, 10, podcast: podcast).reverse }

    it "returns only limited number of episodes" do
      assert_equal episodes.count, podcast.episodes.count
      assert_equal podcast.feed_episodes.count, 10
      podcast.display_episodes_count = 5
      assert_equal podcast.feed_episodes.count, 5
    end
  end
end
