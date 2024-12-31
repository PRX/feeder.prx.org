class CreateSubscribeLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :subscribe_links do |t|
      t.timestamps
      t.string :href
      t.string :text
      t.string :type
    end
  end
end
