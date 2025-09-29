class AddAdvertisingTagsToMegaphoneConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :megaphone_configs, :advertising_tags, :text
  end
end
