# frozen_string_literal: true

class AddAppleCutoverConstraints < ActiveRecord::Migration[7.2]
  def up
    # Apple is integration 0. Other integrations and non-episode sync logs may
    # remain unscoped.
    add_check_constraint :sync_logs,
      "integration IS DISTINCT FROM 0 OR feeder_type <> 'episodes' OR external_show_id IS NOT NULL",
      name: "apple_episode_sync_logs_require_show", validate: false
    add_check_constraint :integrations_episode_delivery_statuses,
      "integration IS DISTINCT FROM 0 OR apple_show_id IS NOT NULL",
      name: "apple_delivery_statuses_require_show", validate: false
    add_check_constraint :apple_podcast_containers, "apple_show_id IS NOT NULL",
      name: "apple_podcast_containers_require_show", validate: false

    Apple::ShowFeedBinding::Backfill.backfill!
    Apple::EpisodeDeliveryIdentityBackfill.backfill!

    unbound_config_ids = connection.select_values(
      "SELECT id FROM apple_configs WHERE show_feed_binding_id IS NULL ORDER BY id"
    )
    if unbound_config_ids.any?
      raise ActiveRecord::MigrationError, "Apple configs missing show feed bindings: #{unbound_config_ids.join(", ")}"
    end

    # Scan existing rows after both backfills. Any remaining NULL identity
    # fails the migration and rolls back the schema and data changes together.
    validate_check_constraint :sync_logs, name: "apple_episode_sync_logs_require_show"
    validate_check_constraint :integrations_episode_delivery_statuses, name: "apple_delivery_statuses_require_show"
    validate_check_constraint :apple_podcast_containers, name: "apple_podcast_containers_require_show"
    change_column_null :apple_configs, :show_feed_binding_id, false
    change_column_null :apple_podcast_containers, :apple_show_id, false
    remove_check_constraint :apple_podcast_containers, name: "apple_podcast_containers_require_show"
  end

  def down
    change_column_null :apple_configs, :show_feed_binding_id, true
    change_column_null :apple_podcast_containers, :apple_show_id, true
    remove_check_constraint :integrations_episode_delivery_statuses, name: "apple_delivery_statuses_require_show"
    remove_check_constraint :sync_logs, name: "apple_episode_sync_logs_require_show"
  end
end
