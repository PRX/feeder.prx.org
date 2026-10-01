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
    raise ActiveRecord::IrreversibleMigration,
      "The original Apple subscription feed types were not preserved"
  end
end
