class CreateMegaphoneConfigs < ActiveRecord::Migration[7.2]
  def change
    create_table :megaphone_configs do |t|
      t.string :token
      t.string :network_id
      t.string :network_name
      t.boolean "publish_enabled", default: false, null: false
      t.bigint "feed_id", null: false

      t.timestamps
    end
  end
end
