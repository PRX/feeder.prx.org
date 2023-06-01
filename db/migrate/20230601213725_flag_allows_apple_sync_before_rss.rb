class FlagAllowsAppleSyncBeforeRss < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_configs, :sync_blocks_rss, :boolean, default: false, null: false
  end
end
