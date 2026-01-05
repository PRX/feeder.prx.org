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

    it "calculates max attempts from episodes" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 3)
      episode2.apple_episode_delivery_status.update!(asset_processing_attempts: 5)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: Apple::DeliveryFileTimeoutError::STAGE_PROCESSING)

      assert_equal 5, error.attempts
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
    it "returns warn for attempts 0-4" do
      (0..4).each do |attempts|
        episode1.apple_episode_delivery_status.update!(asset_processing_attempts: attempts)
        episode2.apple_episode_delivery_status.update!(asset_processing_attempts: 0)

        error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
        assert_equal :warn, error.log_level, "Expected warn for #{attempts} attempts"
      end
    end

    it "returns error for attempt 5" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 5)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
      assert_equal :error, error.log_level
    end

    it "returns fatal for attempts > 5" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 6)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
      assert_equal :fatal, error.log_level
    end
  end

  describe "#raise_publishing_error?" do
    it "returns false for warn level" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 2)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
      refute error.raise_publishing_error?
    end

    it "returns true for error level" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 5)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
      assert error.raise_publishing_error?
    end

    it "returns true for fatal level" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 6)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)
      assert error.raise_publishing_error?
    end
  end

  describe "#log_error!" do
    it "logs at the appropriate level with context" do
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 3)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)

      logs = capture_json_logs do
        error.log_error!
      end

      log = logs.find { |l| l["msg"].include?("Timeout waiting for delivery") }
      assert log.present?
      assert_equal 40, log["level"]  # warn level
      assert_equal "delivery", log["timeout_stage"]
    end

    it "escalates log level based on attempts" do
      expected_levels = [
        [0, 40],  # warn
        [4, 40],  # warn
        [5, 50],  # error
        [6, 60]   # fatal
      ]

      expected_levels.each do |(attempts, expected_level)|
        episode1.apple_episode_delivery_status.update!(asset_processing_attempts: attempts)
        episode2.apple_episode_delivery_status.update!(asset_processing_attempts: 0)

        error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :processing)

        logs = capture_json_logs do
          error.log_error!
        end

        log = logs.find { |l| l["msg"].include?("Timeout waiting for processing") }
        assert log.present?, "Expected log for #{attempts} attempts"
        assert_equal expected_level, log["level"], "Expected level #{expected_level} for #{attempts} attempts"
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
      episode1.apple_episode_delivery_status.update!(asset_processing_attempts: 3)

      error = Apple::DeliveryFileTimeoutError.new(episodes, stage: :delivery)

      assert_match(/Timeout waiting for delivery/, error.message)
      assert_match(/Episodes:/, error.message)
      assert_match(/Attempts: 3/, error.message)
    end
  end
end
