class PodcastStrToText < ActiveRecord::Migration[4.2]
  def up
    change_column :podcasts, :title, :text
    change_column :podcasts, :subtitle, :text
    change_column :podcasts, :summary, :text
  end

  def down
    change_column :podcasts, :title, :string
    change_column :podcasts, :subtitle, :string
    change_column :podcasts, :summary, :string
  end
end
