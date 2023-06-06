require "test_helper"

describe PublishingQueueItem do
  let(:podcast) { create(:podcast) }

  describe "#publishing_attempt" do
    it "can has one publishing attempt" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert_equal [], pqi.publishing_pipeline_states

      pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      assert_equal [pa], pqi.reload.publishing_pipeline_states
    end
  end

  describe ".latest_completed" do
    it "returns the most recent queue items for each podcast that is complete" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      completed_pa = pa2.complete_publishing!

      podcast2 = create(:podcast)
      _pa3 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert_equal [completed_pa.publishing_queue_item], PublishingQueueItem.latest_completed
      assert_equal [], PublishingQueueItem.latest_completed.where(podcast: podcast2)
    end
  end

  describe ".latest_attempted" do
    it "returns the most recent publishing attempt for each podcast" do
      pqi1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      pqi2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      pqi3 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi3, pqi2, pqi1], PublishingQueueItem.latest_attempted
      assert_equal pqi3.created_at, PublishingQueueItem.latest_attempted.first.created_at
    end
  end

  describe ".all_unfinished_items" do
    let(:podcast2) { create(:podcast) }
    it "returns the publishing queue items across all podcasts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, complete: true)

      pqi_2 = PublishingQueueItem.create!(podcast: podcast2)
      _pa = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: pqi_2, complete: true)
      assert_equal [], PublishingQueueItem.all_unfinished_items

      unfinished_pqi = PublishingQueueItem.create!(podcast: podcast)
      unfinished_pqi_2 = PublishingQueueItem.create!(podcast: podcast2)

      assert_equal [unfinished_pqi, unfinished_pqi_2], PublishingQueueItem.all_unfinished_items

      # now create some in-progress work, does not affect the unfinished queue
      PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: unfinished_pqi, complete: false)
      PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: unfinished_pqi_2, complete: false)
      assert_equal [unfinished_pqi, unfinished_pqi_2], PublishingQueueItem.all_unfinished_items

      # now complete the work for podcast 2
      PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: unfinished_pqi_2, complete: true)
      assert_equal [unfinished_pqi], PublishingQueueItem.all_unfinished_items
    end
  end

  describe ".unfinished_items" do
    it "returns the publishing queue items if there are no attempts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert_equal [pqi], PublishingQueueItem.unfinished_items(podcast)
    end

    it "returns the publishing queue items if there is no completed attempts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, complete: false)
      assert_equal [pqi], PublishingQueueItem.unfinished_items(podcast)
    end

    it "returns the publishing queue items only of there are subsequent to completed work" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, complete: true)
      assert_equal [], PublishingQueueItem.unfinished_items(podcast)

      unfinished_pqi = PublishingQueueItem.create!(podcast: podcast)
      assert_equal [unfinished_pqi], PublishingQueueItem.unfinished_items(podcast)

      # now create some in-progress work, does not affect the unfinished queue
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: unfinished_pqi, complete: false)
      assert_equal [unfinished_pqi], PublishingQueueItem.unfinished_items(podcast)
    end
  end

  describe ".settled_work?" do
    it "is settled if there is no work going on" do
      _pqi = PublishingQueueItem.create!(podcast: podcast)
      assert PublishingQueueItem.settled_work?(podcast)
    end

    it "returns the publishing queue items if there is no completed attempts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, complete: false)
      refute PublishingQueueItem.settled_work?(podcast)
    end

    it "returns the publishing queue items only of there are subsequent to completed work" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, complete: true)
      assert PublishingQueueItem.settled_work?(podcast)

      unfinished_pqi = PublishingQueueItem.create!(podcast: podcast)

      # The queue is settled because there is no work going on.
      assert PublishingQueueItem.settled_work?(podcast)

      # now create some in-progress work
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: unfinished_pqi, complete: false)
      refute PublishingQueueItem.settled_work?(podcast)
    end
  end
end
