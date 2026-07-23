class AddShowFeedBindingToAppleConfigs < ActiveRecord::Migration[7.2]
  def change
    add_reference :apple_configs, :show_feed_binding, foreign_key: {to_table: :apple_show_feed_bindings}
  end
end
