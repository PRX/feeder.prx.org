require "test_helper"

describe PublishingPipelineState do
  let(:podcast) { create(:podcast) }

  describe "validations" do
    it "validates the podcast ids match" do
      pqi = PublishingQueueItem.create!(podcast: podcast)

      unrelated_podcast = create(:podcast)
      assert_raises ActiveRecord::RecordInvalid do
        PublishingPipelineState.create!(podcast: unrelated_podcast, publishing_queue_item: pqi)
      end
    end
  end

  describe "attempt!" do
    it "guards if there is already work" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))

      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "guards if all the work is completed" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast), status: :completed)

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
      refute PublishingPipelineState.last.completed?

      assert_difference "PublishingPipelineState.count", 1 do
        res = PublishingPipelineState.complete!(podcast)
        assert_equal res.class, PublishingPipelineState
        assert res.completed?
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

  describe ".expired_pipelines" do
    it "returns expired publishing pipelines" do
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.start!(podcast)
      assert_equal [pa1, pa2], PublishingPipelineState.unfinished_pipelines
      assert_equal [], PublishingPipelineState.expired_pipelines

      refute PublishingPipelineState.expired?(podcast)

      # it gets partially through the pipeline
      pa2.update!(created_at: 29.minutes.ago)
      assert_equal [], PublishingPipelineState.expired_pipelines
      refute PublishingPipelineState.expired?(podcast)

      # and times out
      pa2.update!(created_at: 30.minutes.ago)
      assert_equal [pa1, pa2], PublishingPipelineState.expired_pipelines
      assert PublishingPipelineState.expired?(podcast)

      pa2.update!(created_at: 2.hours.ago)
      assert_equal [pa1, pa2], PublishingPipelineState.expired_pipelines
      assert PublishingPipelineState.expired?(podcast)
    end

    it "shows expired pipelines with multiple and combinations of podcasts" do
      podcast2 = create(:podcast)
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert_equal [], PublishingPipelineState.expired_pipelines
      refute PublishingPipelineState.expired?(podcast)
      refute PublishingPipelineState.expired?(podcast2)

      # they are both expired
      pa1.update!(created_at: 30.minutes.ago)
      pa2.update!(created_at: 30.minutes.ago)
      assert_equal [pa1, pa2], PublishingPipelineState.expired_pipelines
      assert PublishingPipelineState.expired?(podcast)
      assert PublishingPipelineState.expired?(podcast2)

      # just one is expired
      pa1.update(created_at: Time.now)
      assert_equal [pa2], PublishingPipelineState.expired_pipelines
      refute PublishingPipelineState.expired?(podcast)
      assert PublishingPipelineState.expired?(podcast2)
    end
  end

  describe ".expire_pipelines!" do
    it "marks all the pipelines that have timed out as expired" do
      podcast2 = create(:podcast)
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      pa1.update!(created_at: 30.minutes.ago)
      pa2.update!(created_at: 30.minutes.ago)

      assert_equal [pa1, pa2], PublishingPipelineState.expired_pipelines
      PublishingPipelineState.expire_pipelines!

      assert_equal ["created", "expired"], PublishingPipelineState.latest_pipeline(podcast).map(&:status)
      assert_equal ["created", "expired"], PublishingPipelineState.latest_pipeline(podcast2).map(&:status)

      # All pipelines are in a terminal state
      # There is nothing running:
      assert_equal [], PublishingPipelineState.running_pipelines
      assert_equal [], PublishingPipelineState.expired_pipelines

      refute PublishingPipelineState.expired?(podcast)
      refute PublishingPipelineState.expired?(podcast2)
    end
  end

  describe "#publishing_queue_item" do
    it "has one publish queue item per attempt state" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert pqi.publishing_pipeline_states.empty?

      pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      assert pqi.reload.publishing_pipeline_states.present?
      refute pqi.latest_attempt.completed?

      # raises an error if we try to create a second attempt
      assert_raises ActiveRecord::RecordNotUnique do
        PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      end

      # but we can create a second attempt that is marked as complete
      pa2 = pa.complete_publishing!

      assert_equal pa2, PublishingPipelineState.latest_attempt(podcast)
      assert_equal pa2, pqi.reload.latest_attempt
      assert_equal [pa, pa2], pqi.publishing_pipeline_states
      assert pa2.completed?
    end
  end

  describe "PublishFeedJob" do
    before do
      PublishingQueueItem.create!(podcast: podcast)
    end

    describe "error!" do
      it 'sets the status to "error"' do
        PublishFeedJob.stub_any_instance(:publish_feed, ->(*args) { raise "error" }) do
          assert_raises(RuntimeError) { PublishingPipelineState.attempt!(podcast, perform_later: false) }
        end

        assert_equal ["created", "started", "errored"].sort, PublishingPipelineState.where(podcast: podcast).map(&:status).sort
      end
    end

    describe "complete!" do
      it 'sets the status to "complete"' do
        PublishFeedJob.stub_any_instance(:publish_feed, "pub!") do
          PublishingPipelineState.attempt!(podcast, perform_later: false)
        end

        assert_equal ["created", "started", "completed"], PublishingPipelineState.where(podcast: podcast).map(&:status)
      end

      it "attempts new publishing pipelines" do
        # And another request comes along to publish:
        PublishingQueueItem.create!(podcast: podcast)

        PublishFeedJob.stub_any_instance(:publish_feed, "pub!") do
          PublishingPipelineState.attempt!(podcast, perform_later: false)
        end

        PublishingQueueItem.create!(podcast: podcast)

        # Just fire off the job async, so we can see the created state
        PublishingPipelineState.attempt!(podcast, perform_later: true)

        assert_equal ["created", "started", "completed", "created"], PublishingPipelineState.where(podcast: podcast).map(&:status)
      end
    end
  end
end
