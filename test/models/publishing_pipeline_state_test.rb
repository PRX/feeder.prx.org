require "test_helper"

describe PublishingPipelineState do
  let(:podcast) { create(:podcast) }

  describe "attempt!" do
    it "guards if there is already work" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))

      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "guards if all the work is completed" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast), complete: true)

      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "guards if there is no items" do
      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "creates a new attempt" do
      PublishingQueueItem.create!(podcast: podcast)

      assert_difference "PublishingPipelineState.count", 1 do
        res = PublishingPipelineState.attempt!(podcast)
        assert_equal PublishFeedJob, res.class
      end
    end
  end

  describe "complete!" do
    it "guards if there is no settled work" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))

      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "creates a new attempt" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      refute PublishingPipelineState.last.complete?

      assert_difference "PublishingPipelineState.count", 1 do
        res = PublishingPipelineState.complete!(podcast)
        assert_equal res.class, PublishingPipelineState
        assert res.complete?
      end
    end
  end

  describe "latest_attempt" do
    it "returns the most recent publishing attempt" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))

      assert_equal pa2, PublishingPipelineState.latest_attempt(podcast)
    end

    it "returns nil if there are no publishing attempts" do
      assert_nil PublishingPipelineState.latest_attempt(podcast)
    end

    it "ignores other podcasts" do
      podcast2 = create(:podcast)
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      _pa2 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert_equal pa1, PublishingPipelineState.latest_attempt(podcast)
    end
  end

  describe "#publishing_queue_item" do
    it "has one publish queue item per attempt state" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert pqi.publishing_pipeline_states.empty?

      pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      assert pqi.reload.publishing_pipeline_states.present?
      refute pqi.latest_attempt.complete?

      # raises an error if we try to create a second attempt
      assert_raises ActiveRecord::RecordNotUnique do
        PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      end

      # but we can create a second attempt that is marked as complete
      pa2 = pa.complete_publishing!

      assert_equal pa2, PublishingPipelineState.latest_attempt(podcast)
      assert_equal pa2, pqi.reload.latest_attempt
      assert_equal [pa, pa2], pqi.publishing_pipeline_states
      assert pa2.complete?
    end
  end
end
