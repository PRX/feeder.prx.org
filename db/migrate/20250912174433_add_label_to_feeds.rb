class AddLabelToFeeds < ActiveRecord::Migration[7.2]
  def up
    add_column :feeds, :label, :text

    # set label to be the title
    Feed.with_deleted.custom.update_all("label = title")

    # nil out titles that are exactly the same as the podcast
    Feed.with_deleted.custom.joins(:podcast).where("feeds.title = podcasts.title").find_each do |f|
      f.label = nil
      f.save!(validate: false)
    end
  end

  def down
    Feed.with_deleted.custom.joins(:podcast).where(title: nil).find_each do |f|
      f.update!(title: f.label)
    end

    remove_column :feeds, :label
  end
end
