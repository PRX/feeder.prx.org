class DelegatedDeliveryProbesForMediaVersion < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_episode_delivery_statuses, :source_url, :string
    add_column :apple_episode_delivery_statuses, :source_filename, :string
    add_column :apple_episode_delivery_statuses, :source_size, :bigint
    add_column :apple_episode_delivery_statuses, :enclosure_url, :text
    add_column :apple_episode_delivery_statuses, :source_fetch_count, :integer, default: 0

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT into apple_episode_delivery_statuses (delivered, episode_id, source_url, source_filename, source_size, enclosure_url, source_fetch_count, created_at)
            SELECT delivered, ds.episode_id, pc.source_url, pc.source_filename, pc.source_size, pc.enclosure_url, pc.source_fetch_count, now()
            FROM (SELECT max(id) as delivery_status_id, episode_id FROM apple_episode_delivery_statuses GROUP BY episode_id) ds
            JOIN apple_episode_delivery_statuses s ON s.id = ds.delivery_status_id
            JOIN apple_podcast_containers pc ON pc.episode_id = ds.episode_id;
        SQL
      end

      dir.down do
        execute <<~SQL
          UPDATE apple_podcast_containers pc
            SET source_url = s.source_url,
                source_filename = s.source_filename,
                source_size = s.source_size,
                enclosure_url = s.enclosure_url,
                source_fetch_count = s.source_fetch_count
            FROM
              (
                SELECT inner_s.*
                FROM (SELECT max(id) as delivery_status_id, episode_id FROM apple_episode_delivery_statuses GROUP BY episode_id) ds
                JOIN apple_episode_delivery_statuses inner_s ON inner_s.id = ds.delivery_status_id
                JOIN apple_podcast_containers pc ON pc.episode_id = ds.episode_id) s
            WHERE pc.episode_id = s.episode_id;

        SQL
      end

      add_column :apple_episode_delivery_statuses, :source_media_version_id, :bigint
    end
  end
end
