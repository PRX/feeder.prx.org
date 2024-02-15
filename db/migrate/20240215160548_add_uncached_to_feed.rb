class AddUncachedToFeed < ActiveRecord::Migration[7.0]
  def change
    add_column :feeds, :uncached, :boolean, default: false

    # make all apple delegated delivery feeds uncached
    Feed.where(id: Apple::Config.pluck(:private_feed_id)).update_all(uncached: true)
  end
end
