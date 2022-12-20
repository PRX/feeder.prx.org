class AddITunesBlock < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :itunes_block, :boolean, default: false
    add_column :episodes, :itunes_block, :boolean, default: false
  end
end
