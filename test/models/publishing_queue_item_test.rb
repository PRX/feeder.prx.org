require "test_helper"

describe PublishingQueueItem do
  let(:podcast) { create(:podcast) }

  describe "#pubishing_pipeline_states" do
    it "has many pipeline states" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert_equal [], pqi.publishing_pipeline_states

      pps = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      pps2 = PublishingPipelineState.complete!(podcast)

      assert_equal [pps, pps2].sort, pqi.reload.publishing_pipeline_states.sort
    end
  end

  describe ".latest_complete" do
    it "returns the most recent queue items for each podcast that is complete" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      complete_pa = pa2.complete_publishing!

      podcast2 = create(:podcast)
      _pa3 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert_equal [complete_pa.publishing_queue_item], PublishingQueueItem.latest_complete
      assert PublishingQueueItem.latest_complete.where(podcast: podcast2).empty?
    end
  end

  describe ".latest_attempted" do
    it "returns the most recent publishing attempt for each podcast" do
      pqi1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      pqi2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      pqi3 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi1, pqi2, pqi3].sort, PublishingQueueItem.unfinished_items(podcast).sort
      assert_equal [pqi3].sort, PublishingQueueItem.latest_attempted.sort
      assert_equal pqi3.created_at, PublishingQueueItem.latest_attempted.first.created_at
    end
  end

  describe ".latest_failed" do
    it "returns the most recent failed publishing attempt for each podcast" do
      pqi1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      PublishingPipelineState.error!(podcast)

      _pqi2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      PublishingPipelineState.complete!(podcast)

      pqi3 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi3].sort, PublishingQueueItem.unfinished_items(podcast).sort
      assert_equal [pqi1].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)

      PublishingPipelineState.error!(podcast)
      assert_equal [pqi3].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
    end

    it "can be combined with other scopes to query the current failed item" do
      # create a failed item, transition to `created` pipeline state and then transition to `error`
      pqi1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      PublishingPipelineState.error!(podcast)

      assert_equal [pqi1].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [pqi1].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)

      pqi2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi1].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)

      PublishingPipelineState.error!(podcast)

      assert_equal [pqi2].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [pqi2].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)

      _pqi3 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi2].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)
    end

    it "returns the most recent expired publishing attempt for each podcast" do
      pqi1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      PublishingPipelineState.expire!(podcast)

      assert_equal [pqi1].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [pqi1].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)

      _pqi2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi1].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)
    end

    it "includes intermediate states like error_integration" do
      pqi1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item
      PublishingPipelineState.error_integration!(podcast)

      assert_equal [pqi1].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [pqi1].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)
      assert_equal [podcast], PublishingPipelineState.latest_failed_podcasts

      _pqi2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast)).publishing_queue_item

      assert_equal [pqi1].sort, PublishingQueueItem.latest_failed.where(podcast: podcast)
      assert_equal [].sort, PublishingQueueItem.latest_attempted.latest_failed.where(podcast: podcast)
    end
  end

  describe ".all_unfinished_items" do
    let(:podcast2) { create(:podcast) }
    it "returns the publishing queue items across all podcasts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: :complete)

      pqi_2 = PublishingQueueItem.create!(podcast: podcast2)
      _pa = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: pqi_2, status: :complete)
      assert PublishingQueueItem.all_unfinished_items.empty?

      unfinished_pqi = PublishingQueueItem.create!(podcast: podcast)
      unfinished_pqi_2 = PublishingQueueItem.create!(podcast: podcast2)

      assert_equal [unfinished_pqi, unfinished_pqi_2].sort, PublishingQueueItem.all_unfinished_items.sort

      # now create some in-progress work, does not affect the unfinished queue
      PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: unfinished_pqi, status: :started)
      PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: unfinished_pqi_2, status: :started)
      assert_equal [unfinished_pqi, unfinished_pqi_2].sort, PublishingQueueItem.all_unfinished_items.sort

      # now complete the work for podcast 2
      PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: unfinished_pqi_2, status: :complete)
      assert_equal [unfinished_pqi].sort, PublishingQueueItem.all_unfinished_items.sort
    end
  end

  describe ".unfinished_items" do
    it "returns the publishing queue items if there are no attempts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert_equal [pqi].sort, PublishingQueueItem.unfinished_items(podcast).sort
    end

    it "returns the publishing queue items if there is no complete attempts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: :started)
      assert_equal [pqi].sort, PublishingQueueItem.unfinished_items(podcast).sort
    end

    it "returns the publishing queue items only of there are subsequent to completed work" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: :complete)
      assert PublishingQueueItem.unfinished_items(podcast).empty?

      unfinished_pqi = PublishingQueueItem.create!(podcast: podcast)
      assert_equal [unfinished_pqi].sort, PublishingQueueItem.unfinished_items(podcast).sort

      # now create some in-progress work, does not affect the unfinished queue
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: unfinished_pqi, status: :started)
      assert_equal [unfinished_pqi].sort, PublishingQueueItem.unfinished_items(podcast).sort
    end
  end

  describe ".settled_work?" do
    it "is settled if there is no work going on" do
      _pqi = PublishingQueueItem.create!(podcast: podcast)
      assert PublishingQueueItem.settled_work?(podcast)
    end

    it "returns the publishing queue items if there is no completed attempts" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: :started)
      refute PublishingQueueItem.settled_work?(podcast)
    end

    it "returns the publishing queue items only of there are subsequent to completed work" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: :complete)
      assert PublishingQueueItem.settled_work?(podcast)

      unfinished_pqi = PublishingQueueItem.create!(podcast: podcast)

      # The queue is settled because there is no work going on.
      assert PublishingQueueItem.settled_work?(podcast)

      # now create some in-progress work
      _pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: unfinished_pqi, status: :started)
      refute PublishingQueueItem.settled_work?(podcast)
    end
  end

  describe ".delivery_status" do
    it "should provide the delivery status in the exchange delivery log style" do
      podcast = create(:podcast)

      pod1_pqi1 = PublishingQueueItem.create!(podcast: podcast)
      PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pod1_pqi1)
      PublishingPipelineState.complete!(podcast)

      # create a new request that was debouced
      pod1_pqi2 = PublishingQueueItem.create!(podcast: podcast)

      pod1_pqi3 = PublishingQueueItem.create!(podcast: podcast)
      PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pod1_pqi3)
      PublishingPipelineState.start!(podcast)

      podcast2 = create(:podcast)
      pod2_pqi1 = PublishingQueueItem.create!(podcast: podcast2)
      PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: pod2_pqi1)

      assert_equal 4, PublishingQueueItem.delivery_status.to_a.size

      # look at some status output:
      assert_equal [
        {"id" => pod1_pqi1.id, "podcast_id" => podcast.id, "last_pipeline_state" => "complete", "status" => 4},
        {"id" => pod1_pqi2.id, "podcast_id" => podcast.id, "last_pipeline_state" => nil, "status" => nil},
        {"id" => pod1_pqi3.id, "podcast_id" => podcast.id, "last_pipeline_state" => "started", "status" => 1},
        {"id" => pod2_pqi1.id, "podcast_id" => podcast2.id, "last_pipeline_state" => "created", "status" => 0}
      ], PublishingQueueItem.delivery_status.order(podcast_id: :asc, created_at: :asc).as_json(except: [:created_at, :updated_at])
    end
  end
end
