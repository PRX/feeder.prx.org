require "test_helper"

describe PublishingAttempt do
  let(:podcast) { create(:podcast) }

  describe "latest_attempt" do
    it "returns the most recent publishing attempt" do
      _pa1 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))

      assert_equal pa2, PublishingAttempt.latest_attempt(podcast)
    end

    it "returns nil if there are no publishing attempts" do
      assert_nil PublishingAttempt.latest_attempt(podcast)
    end

    it "ignores other podcasts" do
      podcast2 = create(:podcast)
      pa1 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      _pa2 = PublishingAttempt.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert_equal pa1, PublishingAttempt.latest_attempt(podcast)
    end
  end

  describe "#publishing_queue_item" do
    it "has one publish queue item per attempt state" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert pqi.publishing_attempts.empty?

      pa = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: pqi)
      assert pqi.reload.publishing_attempts.present?
      refute pqi.latest_attempt.complete?

      # raises an error if we try to create a second attempt
      assert_raises ActiveRecord::RecordNotUnique do
        PublishingAttempt.create!(podcast: podcast, publishing_queue_item: pqi)
      end

      # but we can create a second attempt that is marked as complete
      pa2 = pa.complete_publishing!

      assert_equal pa2, PublishingAttempt.latest_attempt(podcast)
      assert_equal pa2, pqi.reload.latest_attempt
      assert_equal [pa, pa2], pqi.publishing_attempts
      assert pa2.complete?
    end
  end
end
