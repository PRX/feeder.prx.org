require "test_helper"

describe Apple::DeliveryFileTimeoutError do
  let(:podcast) { create(:podcast) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:apple_config) { create(:apple_config, feed: private_feed) }
  let(:apple_publisher) { apple_config.build_publisher }
  let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
  let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }
  let(:episodes) { [episode1, episode2] }

  describe "#initialize" do
    it "captures episode information" do
      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: Apple::DeliveryFileTimeoutError::STAGE_DELIVERY)

      assert_equal episodes, error.episodes
      assert_equal :delivery, error.timeout_stage
      assert_equal [episode1.feeder_id, episode2.feeder_id], error.episode_ids
    end

    it "calculates max duration from episodes" do
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 1800) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, 3600) do
          error = Apple::DeliveryFileTimeoutError.new(episodes, stage: Apple::DeliveryFileTimeoutError::STAGE_PROCESSING)

          assert_equal 3600, error.asset_wait_duration
        end
      end
    end

    it "captures different timeout stages" do
      delivery_error = Apple::DeliveryFileTimeoutError.new(episodes, stage: Apple::DeliveryFileTimeoutError::STAGE_DELIVERY)
      processing_error = Apple::DeliveryFileTimeoutError.new(episodes, stage: Apple::DeliveryFileTimeoutError::STAGE_PROCESSING)
      stuck_error = Apple::DeliveryFileTimeoutError.new(episodes, stage: Apple::DeliveryFileTimeoutError::STAGE_STUCK)

      assert_equal :delivery, delivery_error.timeout_stage
      assert_equal :processing, processing_error.timeout_stage
      assert_equal :stuck, stuck_error.timeout_stage
    end
  end

  describe "#log_level" do
    it "returns info for duration < 30 minutes" do
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 1799) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, nil) do
          error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
          assert_equal :info, error.log_level
        end
      end
    end

    it "returns warn for duration >= 30 minutes and < 60 minutes" do
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 1800) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, nil) do
          error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
          assert_equal :warn, error.log_level
        end
      end

      episode1.feeder_episode.stub(:measure_asset_processing_duration, 3599) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, nil) do
          error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
          assert_equal :warn, error.log_level
        end
      end
    end

    it "returns error for duration >= 60 minutes" do
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 3600) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, nil) do
          error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
          assert_equal :error, error.log_level
        end
      end
    end
  end

  describe "#log_error!" do
    it "logs at the appropriate level with context" do
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 2000) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, nil) do
          error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)

          logs = capture_json_logs do
            error.log_error!
          end

          log = logs.find { |l| l["msg"].include?("Timeout waiting for delivery") }
          assert log.present?
          assert_equal 40, log["level"] # warn level
          assert_equal "delivery", log["timeout_stage"]
        end
      end
    end

    it "escalates log level based on duration" do
      # [duration_seconds, expected_log_level_int]
      # Bunyan log levels: 30=info, 40=warn, 50=error
      expected_levels = [
        [1000, 30],  # info (< 30 min)
        [1800, 40],  # warn (>= 30 min)
        [3599, 40],  # warn (< 60 min)
        [3600, 50]   # error (>= 60 min)
      ]

      expected_levels.each do |(duration, expected_level)|
        episode1.feeder_episode.stub(:measure_asset_processing_duration, duration) do
          episode2.feeder_episode.stub(:measure_asset_processing_duration, nil) do
            error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :processing)

            logs = capture_json_logs do
              error.log_error!
            end

            log = logs.find { |l| l["msg"].include?("Timeout waiting for processing") }
            assert log.present?, "Expected log for #{duration}s duration"
            assert_equal expected_level, log["level"], "Expected level #{expected_level} for #{duration}s duration"
          end
        end
      end
    end
  end

  describe "#podcast_id" do
    it "returns the podcast id from the first episode" do
      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
      assert_equal episode1.podcast_id, error.podcast_id
    end
  end

  describe "#message" do
    it "includes timeout stage and episode info" do
      episode1.feeder_episode.stub(:measure_asset_processing_duration, 2000) do
        episode2.feeder_episode.stub(:measure_asset_processing_duration, nil) do
          error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)

          assert_match(/Timeout waiting for delivery/, error.message)
          assert_match(/Episodes:/, error.message)
          assert_match(/Asset Wait Duration: 2000/, error.message)
        end
      end
    end
  end
end
