# frozen_string_literal: true

# Backfill tests create legacy rows that predate the cutover constraints.
# Reproduce that schema inside the test transaction, rolling back DDL and data.
module ApplePreCutoverSchema
  def with_apple_pre_cutover_schema
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.transaction(requires_new: true) do
        connection.remove_check_constraint :sync_logs, name: "apple_episode_sync_logs_require_show"
        connection.remove_check_constraint :integrations_episode_delivery_statuses, name: "apple_delivery_statuses_require_show"
        connection.change_column_null :apple_podcast_containers, :apple_show_id, true
        yield
        raise ActiveRecord::Rollback
      end
    end
  end
end
