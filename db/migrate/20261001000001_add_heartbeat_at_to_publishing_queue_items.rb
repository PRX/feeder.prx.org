# frozen_string_literal: true

class AddHeartbeatAtToPublishingQueueItems < ActiveRecord::Migration[7.2]
  def change
    add_column :publishing_queue_items, :heartbeat_at, :datetime
  end
end
