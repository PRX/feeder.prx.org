# frozen_string_literal: true

class EnforceDelegatedDeliveryConfigUniqueness < ActiveRecord::Migration[7.2]
  FEED_INDEX = "index_apple_configs_on_feed_id"
  BINDING_INDEX = "index_apple_configs_on_show_feed_binding_id"

  def up
    verify_unique!(:feed_id)
    verify_unique!(:show_feed_binding_id)
    verify_unique_show_connections!

    replace_index(:feed_id, FEED_INDEX, unique: true)
    replace_index(:show_feed_binding_id, BINDING_INDEX, unique: true)
    add_index :apple_show_feed_bindings, :apple_show_id, unique: true
  end

  def down
    remove_index :apple_show_feed_bindings, :apple_show_id
    replace_index(:feed_id, FEED_INDEX, unique: false)
    replace_index(:show_feed_binding_id, BINDING_INDEX, unique: false)
  end

  private

  def verify_unique_show_connections!
    duplicate_show_ids = select_values(<<~SQL.squish)
      SELECT apple_show_id
      FROM apple_show_feed_bindings
      GROUP BY apple_show_id
      HAVING COUNT(*) > 1
      ORDER BY apple_show_id
    SQL
    return if duplicate_show_ids.empty?

    raise ActiveRecord::MigrationError,
      "Duplicate Apple show connections must be resolved: #{duplicate_show_ids.join(", ")}"
  end

  def verify_unique!(column)
    duplicate_values = select_values(<<~SQL.squish)
      SELECT #{column}
      FROM apple_configs
      WHERE #{column} IS NOT NULL
      GROUP BY #{column}
      HAVING COUNT(*) > 1
      ORDER BY #{column}
    SQL
    return if duplicate_values.empty?

    raise ActiveRecord::MigrationError,
      "Duplicate apple_configs.#{column} values must be resolved: #{duplicate_values.join(", ")}"
  end

  def replace_index(column, name, unique:)
    remove_index :apple_configs, name: name, if_exists: true
    add_index :apple_configs, column, name: name, unique: unique
  end
end
