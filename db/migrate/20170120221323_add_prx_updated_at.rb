class AddPrxUpdatedAt < ActiveRecord::Migration[4.2]
  def up
    add_column :podcasts, :source_updated_at, :datetime
    execute 'UPDATE podcasts SET source_updated_at = updated_at'

    add_column :episodes, :source_updated_at, :datetime
    execute 'UPDATE episodes SET source_updated_at = updated_at'
  end

  def down
    remove_column :podcasts, :source_updated_at
    remove_column :episodes, :source_updated_at
  end
end
