class AddPRXUpdatedAt < ActiveRecord::Migration
  def change
    add_column :podcasts, :source_updated_at, :datetime
    execute 'UPDATE podcasts SET source_updated_at = updated_at'

    add_column :episodes, :source_updated_at, :datetime
    execute 'UPDATE episodes SET source_updated_at = updated_at'
  end
end
