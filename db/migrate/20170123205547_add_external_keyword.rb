class AddExternalKeyword < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :keyword_xid, :string
    add_index :episodes, :keyword_xid, unique: true
  end
end
