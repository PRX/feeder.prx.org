class AddUniquenessConstraints < ActiveRecord::Migration[4.2]
  def change
    add_index :podcasts, :path, unique: true

    remove_index :podcasts, :prx_id
    add_index :podcasts, :prx_id, unique: true

    remove_index :episodes, :prx_id
    add_index :episodes, :prx_id, unique: true
  end
end
