require "test_helper"

class Apple::CutoverConstraintsTest < ActiveSupport::TestCase
  test "database rejects Apple episode logs without a show on insert and update" do
    log = Apple::SyncLog.new(feeder_type: :episodes, feeder_id: 123, external_id: "episode-1")
    assert_check_violation { log.save!(validate: false) }

    log.external_show_id = "show-1"
    log.save!
    assert_check_violation { log.update_column(:external_show_id, nil) }
  end

  test "database permits unscoped non-episode Apple logs and Megaphone episode logs" do
    apple = Apple::SyncLog.create!(feeder_type: :feeds, feeder_id: 123, external_id: "show-1")
    megaphone = SyncLog.create!(integration: :megaphone, feeder_type: :episodes, feeder_id: 123, external_id: "episode-1")

    assert_nil apple.reload.external_show_id
    assert_nil megaphone.reload.external_show_id
  end

  test "database rejects containers without a show on insert and update" do
    container = build(:apple_podcast_container, episode: create(:episode), apple_show_id: nil)
    assert_not_null_violation { container.save!(validate: false) }

    container.apple_show_id = "show-1"
    container.save!
    assert_not_null_violation { container.update_column(:apple_show_id, nil) }
  end

  test "database rejects Apple statuses without a show on insert and update" do
    status = build(:apple_episode_delivery_status, episode: create(:episode), apple_show_id: nil)
    assert_check_violation { status.save!(validate: false) }

    status.apple_show_id = "show-1"
    status.save!
    assert_check_violation { status.update_column(:apple_show_id, nil) }
  end

  test "database permits Megaphone status history without an Apple show" do
    status = create(:megaphone_episode_delivery_status, episode: create(:episode))
    status.mark_as_delivered!

    assert_nil status.reload.apple_show_id
    assert_nil Megaphone::EpisodeDeliveryStatus.current(status.episode).apple_show_id
  end

  private

  def assert_check_violation(&block)
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true, &block)
    end
    assert_instance_of PG::CheckViolation, error.cause
  end

  def assert_not_null_violation(&block)
    assert_raises(ActiveRecord::NotNullViolation) do
      ActiveRecord::Base.transaction(requires_new: true, &block)
    end
  end
end
