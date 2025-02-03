class CreateSubscribeLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :subscribe_links do |t|
      t.timestamps
      t.references :podcast, index: true
      t.boolean :enabled
      t.integer :external_id
      t.string :platform
      t.string :type
    end
  end
end
