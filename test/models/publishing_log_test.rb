require "test_helper"

describe PublishingLog do
  describe "publishing log" do
    let(:podcast) { create(:podcast) }

    it "can has one publishing attempt" do
      pl = PublishingLog.create!(podcast: podcast)
      assert pl.publishing_attempt.nil?

      pa = PublishingAttempt.create!(podcast: podcast, publishing_log: pl, podcast: podcast)
      assert pl.reload.publishing_attempt.present?
    end
  end
end
