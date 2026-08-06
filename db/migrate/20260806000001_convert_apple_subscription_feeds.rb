# frozen_string_literal: true

class ConvertAppleSubscriptionFeeds < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE feeds
      SET type = NULL, updated_at = CURRENT_TIMESTAMP
      WHERE type = 'Feeds::AppleSubscription'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE feeds
      SET type = 'Feeds::AppleSubscription', updated_at = CURRENT_TIMESTAMP
      WHERE id IN (SELECT feed_id FROM apple_configs)
    SQL
  end
end
