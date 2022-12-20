class AddPodcastTags < ActiveRecord::Migration[4.2]
  def up
    add_column :podcasts, :serial_order, :boolean, default: false
    execute 'UPDATE podcasts SET serial_order = false'
  end

  def down
    remove_column :podcasts, :serial_order
  end
end
