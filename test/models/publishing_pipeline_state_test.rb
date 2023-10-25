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

    it "validates the transition is not from a terminal state" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      pps = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: :complete)

      # going from completed to created is not allowed
      assert_raises ActiveRecord::RecordInvalid do
        pps = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: :started)
      end
    end
  end

  describe "attempt!" do
    it "guards if there is already work" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))

      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "guards if all the work is complete" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast), status: :complete)

      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "guards if there is no items" do
      assert_nil PublishingPipelineState.attempt!(podcast)
    end

    it "creates a new attempt" do
      PublishingQueueItem.create!(podcast: podcast)

      assert_difference "PublishingPipelineState.count", 1 do
        res = PublishingPipelineState.attempt!(podcast)
        assert_equal PublishingQueueItem, res.class
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

  describe "most_recent_state" do
    it "returns the most recent publishing attempt" do
      _pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))

      assert_equal pa2, PublishingPipelineState.most_recent_state(podcast)
    end

    it "returns nil if there are no publishing attempts" do
      assert_nil PublishingPipelineState.most_recent_state(podcast)
    end

    it "ignores other podcasts" do
      podcast2 = create(:podcast)
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      _pa2 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert_equal pa1, PublishingPipelineState.most_recent_state(podcast)
    end
  end

  describe ".expired_pipelines" do
    it "returns expired publishing pipelines" do
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.start!(podcast)

      assert_equal [pa1, pa2].sort, PublishingPipelineState.unfinished_pipelines.sort
      assert PublishingPipelineState.expired_pipelines.empty?

      refute PublishingPipelineState.expired?(podcast)

      # it gets partially through the pipeline
      pa2.update_column(:created_at, 29.minutes.ago)
      assert PublishingPipelineState.expired_pipelines.empty?
      refute PublishingPipelineState.expired?(podcast)

      # and times out
      pa2.update_column(:created_at, 30.minutes.ago)
      assert_equal [pa1, pa2].sort, PublishingPipelineState.expired_pipelines.sort
      assert PublishingPipelineState.expired?(podcast)

      pa2.update_column(:created_at, 2.hours.ago)
      assert_equal [pa1, pa2].sort, PublishingPipelineState.expired_pipelines.sort
      assert PublishingPipelineState.expired?(podcast)
    end

    it "shows expired pipelines with multiple and combinations of podcasts" do
      podcast2 = create(:podcast)
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      assert PublishingPipelineState.expired_pipelines.empty?
      refute PublishingPipelineState.expired?(podcast)
      refute PublishingPipelineState.expired?(podcast2)

      # they are both expired
      pa1.update_column(:created_at, 30.minutes.ago)
      pa2.update_column(:created_at, 30.minutes.ago)
      assert_equal [pa1, pa2].sort, PublishingPipelineState.expired_pipelines.sort
      assert PublishingPipelineState.expired?(podcast)
      assert PublishingPipelineState.expired?(podcast2)

      # just one is expired
      pa1.update_column(:created_at, Time.now)
      assert_equal [pa2].sort, PublishingPipelineState.expired_pipelines.sort
      refute PublishingPipelineState.expired?(podcast)
      assert PublishingPipelineState.expired?(podcast2)
    end
  end

  describe ".expire_pipelines!" do
    it "marks all the pipelines that have timed out as expired" do
      podcast2 = create(:podcast)
      pa1 = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast))
      pa2 = PublishingPipelineState.create!(podcast: podcast2, publishing_queue_item: PublishingQueueItem.create!(podcast: podcast2))

      pa1.update_column(:created_at, 30.minutes.ago)
      pa2.update_column(:created_at, 30.minutes.ago)

      assert_equal [pa1, pa2].sort, PublishingPipelineState.expired_pipelines.sort
      PublishingPipelineState.expire_pipelines!

      assert_equal ["created", "expired"].sort, PublishingPipelineState.latest_pipeline(podcast).map(&:status).sort
      assert_equal ["created", "expired"].sort, PublishingPipelineState.latest_pipeline(podcast2).map(&:status).sort

      # All pipelines are in a terminal state
      # There is nothing running:
      assert PublishingPipelineState.running_pipelines.empty?
      assert PublishingPipelineState.expired_pipelines.empty?

      refute PublishingPipelineState.expired?(podcast)
      refute PublishingPipelineState.expired?(podcast2)
    end
  end

  describe ".retry_failed_pipelines!" do
    it "should retry failed pipelines" do
      PublishingPipelineState.start_pipeline!(podcast)
      assert_equal ["created"], PublishingPipelineState.latest_pipeline(podcast).map(&:status)

      # it fails
      PublishingPipelineState.error!(podcast)
      assert_equal ["created", "error"].sort, PublishingPipelineState.latest_pipeline(podcast).map(&:status).sort

      # it retries
      PublishingPipelineState.retry_failed_pipelines!
      assert_equal ["created"].sort, PublishingPipelineState.latest_pipeline(podcast).map(&:status).sort
    end

    it "ignores previously errored pipelines back in the queue" do
      # A failed pipeline
      PublishingPipelineState.start_pipeline!(podcast)
      PublishingPipelineState.error!(podcast)
      assert_equal ["created", "error"].sort, PublishingPipelineState.latest_pipeline(podcast).map(&:status).sort

      # A new pipeline
      PublishingPipelineState.start_pipeline!(podcast)
      PublishingPipelineState.publish_rss!(podcast)
      assert_equal ["created", "published_rss"], PublishingPipelineState.latest_pipeline(podcast).map(&:status)
      publishing_item = PublishingPipelineState.latest_pipeline(podcast).map(&:publishing_queue_item_id).uniq

      # it does not retry the errored pipeline
      PublishingPipelineState.retry_failed_pipelines!
      assert_equal ["created", "published_rss"].sort, PublishingPipelineState.latest_pipeline(podcast).map(&:status).sort
      # it's the same publishing item
      assert_equal publishing_item, PublishingPipelineState.latest_pipeline(podcast).map(&:publishing_queue_item_id).uniq
    end
  end

  describe "#publishing_queue_item" do
    it "has one publish queue item per attempt state" do
      pqi = PublishingQueueItem.create!(podcast: podcast)
      assert pqi.publishing_pipeline_states.empty?

      pa = PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      assert pqi.reload.publishing_pipeline_states.present?
      refute pqi.most_recent_state.complete?

      # raises an error if we try to create a second attempt
      assert_raises ActiveRecord::RecordNotUnique do
        PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi)
      end

      # but we can create a second attempt that is marked as complete
      pa2 = pa.complete_publishing!

      assert_equal pa2, PublishingPipelineState.most_recent_state(podcast)
      assert_equal pa2, pqi.reload.most_recent_state
      assert_equal [pa, pa2].sort, pqi.publishing_pipeline_states.sort
      assert pa2.complete?
    end
  end

  describe "PublishFeedJob" do
    before do
      PublishingQueueItem.create!(podcast: podcast)
    end

    describe "error!" do
      it 'sets the status to "error"' do
        PublishFeedJob.stub_any_instance(:save_file, nil) do
          PublishFeedJob.stub_any_instance(:publish_feed, ->(*args) { raise "error" }) do
            assert_raises(RuntimeError) { PublishingPipelineState.attempt!(podcast, perform_later: false) }
          end
        end

        assert_equal ["created", "started", "error"].sort, PublishingPipelineState.where(podcast: podcast).map(&:status).sort
      end
    end

    describe "complete!" do
      it 'sets the status to "complete"' do
        PublishFeedJob.stub_any_instance(:save_file, nil) do
          PublishFeedJob.stub_any_instance(:publish_feed, "pub!") do
            PublishingPipelineState.attempt!(podcast, perform_later: false)
          end
        end

        assert_equal ["created", "started", "complete"].sort, PublishingPipelineState.where(podcast: podcast).map(&:status).sort
      end

      it "attempts new publishing pipelines" do
        # And another request comes along to publish:
        PublishingQueueItem.create!(podcast: podcast)

        PublishFeedJob.stub_any_instance(:save_file, nil) do
          PublishFeedJob.stub_any_instance(:publish_feed, "pub!") do
            PublishingPipelineState.attempt!(podcast, perform_later: false)
          end
        end

        PublishingQueueItem.create!(podcast: podcast)

        # Just fire off the job async, so we can see the created state
        PublishingPipelineState.attempt!(podcast, perform_later: true)

        assert_equal ["created", "started", "complete", "created"], PublishingPipelineState.where(podcast: podcast).order(id: :asc).map(&:status)
      end
    end

    describe "Apple publishing" do
      before do
        2.times { create(:private_feed, podcast: podcast) }
        podcast.reload

        f1, f2, _f3 = podcast.feeds

        create(:apple_config,
          podcast: podcast,
          public_feed: f1,
          private_feed: f2,
          publish_enabled: true)
      end

      it "can publish via the apple configs" do
        assert_equal 3, podcast.reload.feeds.count

        PublishAppleJob.stub(:perform_now, "published apple!") do
          PublishFeedJob.stub_any_instance(:save_file, "saved rss!") do
            PublishingPipelineState.attempt!(podcast, perform_later: false)
          end
        end
        PublishingPipelineState.complete!(podcast)
        assert_equal(
          ["complete", "published_rss", "published_rss", "published_rss", "published_apple", "started", "created"],
          PublishingPipelineState.order(id: :desc).pluck(:status)
        )
      end
    end
  end
end
