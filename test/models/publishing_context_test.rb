require "test_helper"

describe PublishingContext do
  let(:podcast) { create(:podcast) }

  describe ".heartbeat!" do
    it "does nothing outside a publish job" do
      PublishingPipelineState.stub(:heartbeat!, ->(*) { flunk "beat without a publishing context" }) do
        assert_nil PublishingContext.heartbeat!

        PublishingContext.set(podcast: podcast) { assert_nil PublishingContext.heartbeat! }
      end
    end

    it "beats for the worker's queue item" do
      pqi = PublishingPipelineState.start_pipeline!(podcast)

      PublishingContext.set(podcast: podcast, publishing_queue_item: pqi) do
        PublishingContext.heartbeat!
      end

      refute_nil pqi.reload.heartbeat_at
    end

    it "raises when the worker lost ownership" do
      old_pqi = PublishingPipelineState.start_pipeline!(podcast)
      PublishingPipelineState.expire!(podcast)

      PublishingContext.set(podcast: podcast, publishing_queue_item: old_pqi) do
        assert_raises(PublishingPipelineState::LostOwnershipError) { PublishingContext.heartbeat! }
      end
    end
  end
end
