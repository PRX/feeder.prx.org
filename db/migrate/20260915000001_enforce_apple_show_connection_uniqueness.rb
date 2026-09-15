# frozen_string_literal: true

class EnforceAppleShowConnectionUniqueness < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    duplicate_show_ids = select_values(<<~SQL.squish)
      SELECT apple_show_id
      FROM apple_show_feed_bindings
      GROUP BY apple_show_id
      HAVING COUNT(*) > 1
      ORDER BY apple_show_id
    SQL
    if duplicate_show_ids.any?
      raise ActiveRecord::MigrationError,
        "Duplicate Apple show connections must be resolved: #{duplicate_show_ids.join(", ")}"
    end

    add_index :apple_show_feed_bindings, :apple_show_id, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :apple_show_feed_bindings, :apple_show_id, algorithm: :concurrently
  end
end
