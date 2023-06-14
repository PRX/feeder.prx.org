require "test_helper"

class PublishingStatusTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:episode) { build(:episode, podcast: podcast) }

  describe "#publishing_status" do
    it "calculates based on published_at" do
      e1 = build(:episode, published_at: nil)
      e2 = build(:episode, published_at: 10.hours.from_now)
      e3 = build(:episode, published_at: 10.hours.ago)

      assert_equal "draft", e1.publishing_status
      assert_equal "scheduled", e2.publishing_status
      assert_equal "published", e3.publishing_status
    end

    it "memoizes publishing status" do
      ep = build(:episode, published_at: nil)
      assert_equal "draft", ep.publishing_status

      ep.published_at = Time.now
      assert_equal "draft", ep.publishing_status
    end
  end

  describe "#publishing_status_was" do
    it "returns the previous publishing_status" do
      e1 = create(:episode, podcast: podcast, published_at: nil)
      e2 = create(:episode, podcast: podcast, published_at: 10.hours.from_now)
      e3 = create(:episode, podcast: podcast, published_at: 10.hours.ago)

      e1.published_at = Time.now
      e2.published_at = nil
      e3.published_at = nil

      assert_equal "draft", e1.publishing_status_was
      assert_equal "scheduled", e2.publishing_status_was
      assert_equal "published", e3.publishing_status_was
    end
  end

  describe "#publishing_status=" do
    it "sets an episode to draft" do
      ep = build(:episode, published_at: 10.hours.ago)
      ep.publishing_status = "draft"
      assert_nil ep.published_at
      assert_equal "draft", ep.publishing_status
    end

    it "sets an episode to scheduled" do
      ep = build(:episode, released_at: 10.hours.ago, published_at: nil)
      ep.publishing_status = "scheduled"
      assert_equal ep.released_at, ep.published_at
      assert_equal "scheduled", ep.publishing_status
    end

    it "sets an episode to published" do
      now = Time.now

      Time.stub(:now, now) do
        ep = build(:episode, published_at: nil)
        ep.publishing_status = "published"
        assert_equal now, ep.published_at
        assert_equal now, ep.released_at
      end
    end
  end

  describe "#valid?" do
    it "is valid while draft" do
      episode.published_at = nil
      assert episode.valid?

      episode.publishing_status = "draft"
      assert episode.valid?
    end

    it "checks for non-blank published at" do
      episode.publishing_status = "scheduled"
      episode.published_at = nil
      refute episode.valid?
      assert_includes episode.errors[:published_at], "can't be blank"

      episode.publishing_status = "published"
      episode.published_at = nil
      refute episode.valid?
      assert_includes episode.errors[:published_at], "can't be blank"
    end

    it "checks for scheduled in the future" do
      content = build(:content, episode: episode, status: "complete", position: 1)
      episode.contents << content
      episode.save!

      episode.publishing_status = "scheduled"
      episode.published_at = 10.hours.from_now
      assert episode.valid?

      episode.published_at = 10.hours.ago
      refute episode.valid?
      assert_includes episode.errors[:published_at], "can't be in the past"
    end

    it "checks for published in the past" do
      content = build(:content, episode: episode, status: "complete", position: 1)
      episode.contents << content
      episode.save!

      episode.publishing_status = "published"
      episode.published_at = 10.hours.ago
      assert episode.valid?

      episode.published_at = 10.hours.from_now
      refute episode.valid?
      assert_includes episode.errors[:published_at], "can't be in the future"
    end
  end
end
