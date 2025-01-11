class AddSyncBlocksRssToMegaphoneConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :megaphone_configs, :sync_blocks_rss, :boolean, default: false, null: false
  end
end
