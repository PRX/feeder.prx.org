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
    it "has one logged call to publish per attempt" do
      pl = PublishingQueueItem.create!(podcast: podcast)
      assert pl.publishing_attempt.nil?

      pa = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: pl)
      assert pl.reload.publishing_attempt.present?

      # raises an error if we try to create a second attempt
      assert_raises ActiveRecord::RecordNotUnique do
        PublishingAttempt.create!(podcast: podcast, publishing_queue_item: pl)
      end
    end
  end
end
