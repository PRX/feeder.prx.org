require "test_helper"

describe PublishingQueueItem do
  let(:podcast) { create(:podcast) }

  describe "#publishing_attempt" do
    it "can has one publishing attempt" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert_equal [], pqi.publishing_attempts

      pa = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: pqi)
      assert_equal [pa], pqi.reload.publishing_attempts
    end
  end

  describe ".latest_completed" do
    it "returns the most recent queue items for each podcast that is complete" do
      _pa1 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      completed_pa = pa2.complete_publishing!

      podcast2 = create(:podcast)
      _pa3 = PublishingAttempt.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert_equal [completed_pa.publishing_queue_item], PublishingQueueItem.latest_completed
      assert_equal [], PublishingQueueItem.latest_completed.where(podcast: podcast2)
    end
  end

  describe ".latest_attempted" do
    it "returns the most recent publishing attempt for each podcast" do
      pqi1 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      pqi2 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      pqi3 = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi3, pqi2, pqi1], PublishingQueueItem.latest_attempted
      assert_equal pqi3.created_at, PublishingQueueItem.latest_attempted.first.created_at
    end
  end
end
