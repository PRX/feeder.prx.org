require "test_helper"

describe PublishingQueueItem do
  describe "#publishing_attempt" do
    let(:podcast) { create(:podcast) }

    it "can has one publishing attempt" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert pqi.publishing_attempt.nil?

      pa = PublishingAttempt.create!(podcast: podcast, publishing_queue_item: pqi)
      assert pl.reload.publishing_attempt.present?
    end
  end
end
