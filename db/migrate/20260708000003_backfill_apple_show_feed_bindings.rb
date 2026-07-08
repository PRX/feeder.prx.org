class BackfillAppleShowFeedBindings < ActiveRecord::Migration[7.2]
  def up
    Apple::ShowFeedBinding.reset_column_information
    Apple::Config.reset_column_information
    Apple::ShowFeedBinding.backfill_show_feed_bindings!
  end

  def down
  end
end
