# frozen_string_literal: true

class AddAccountIdToAppleKeys < ActiveRecord::Migration[7.2]
  def up
    add_column :apple_keys, :account_id, :bigint
    add_index :apple_keys, :account_id

    original_key_row_ids = select_values("SELECT id FROM apple_keys ORDER BY id").map(&:to_i)
    references_by_key = apple_key_references.group_by { |reference| reference.fetch(:original_key_row_id) }
    unowned_key_row_ids = original_key_row_ids - references_by_key.keys
    if unowned_key_row_ids.any?
      raise ActiveRecord::MigrationError, "Apple keys have no feed/account references: #{unowned_key_row_ids.join(", ")}"
    end

    # Split each existing row independently, even when credentials are identical.
    original_key_row_ids.each do |original_key_row_id|
      references_by_account = references_by_key.fetch(original_key_row_id)
        .group_by { |reference| reference.fetch(:account_id) }
      account_ids = references_by_account.keys.sort

      # The first account keeps the original row; consume the rest to create copies.
      retained_account_id = account_ids.shift
      execute <<~SQL.squish
        UPDATE apple_keys
        SET account_id = #{retained_account_id}
        WHERE id = #{original_key_row_id}
      SQL

      while (account_id = account_ids.shift)
        copied_key_row_id = select_value(<<~SQL.squish).to_i
          INSERT INTO apple_keys (provider_id, key_id, key_pem_b64, created_at, updated_at, account_id)
          SELECT provider_id, key_id, key_pem_b64, created_at, updated_at, #{account_id}
          FROM apple_keys
          WHERE id = #{original_key_row_id}
          RETURNING id
        SQL

        # This account_id could span multiple delegated delivery configs
        config_ids = references_by_account.fetch(account_id).map { |reference| reference.fetch(:config_id).to_i }

        repoint_configs(config_ids, copied_key_row_id, account_id)
      end
    end

    change_column_null :apple_keys, :account_id, false
  end

  def down
    remove_index :apple_keys, :account_id
    remove_column :apple_keys, :account_id
  end

  private

  def apple_key_references
    select_all(<<~SQL.squish).map do |row|
      SELECT apple_configs.id AS config_id,
             apple_configs.key_id AS original_key_row_id,
             substring(podcasts.prx_account_uri FROM '(?:^|/)([0-9]+)/?$')::bigint AS account_id
      FROM apple_configs
      JOIN feeds ON feeds.id = apple_configs.feed_id
      JOIN podcasts ON podcasts.id = feeds.podcast_id
      WHERE apple_configs.key_id IS NOT NULL
    SQL
      reference = row.symbolize_keys
      if reference.fetch(:account_id).to_i.zero?
        raise ActiveRecord::MigrationError, "Invalid PRX account URI for apple_configs #{reference.fetch(:config_id)}"
      end
      reference
    end
  end

  def repoint_configs(config_ids, copied_key_row_id, account_id)
    execute <<~SQL.squish
      UPDATE apple_configs
      SET key_id = #{copied_key_row_id}
      FROM feeds
      JOIN podcasts ON podcasts.id = feeds.podcast_id
      WHERE apple_configs.feed_id = feeds.id
        AND apple_configs.id IN (#{config_ids.join(", ")})
        AND substring(podcasts.prx_account_uri FROM '(?:^|/)([0-9]+)/?$')::bigint = #{account_id}
    SQL
  end
end
