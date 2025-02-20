class CreateSubscribeLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :subscribe_links do |t|
      t.timestamps
      t.references :podcast, index: true
      t.string :external_id
      t.string :platform
    end
  end
end
