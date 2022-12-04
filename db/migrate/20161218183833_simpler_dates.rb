class SimplerDates < ActiveRecord::Migration[4.2]
  def up
    execute 'update podcasts set published_at = pub_date where pub_date is not null and pub_date > published_at'
    execute 'update podcasts set updated_at = last_build_date where last_build_date is not null and last_build_date > updated_at'
    remove_column :podcasts, :last_build_date
    remove_column :podcasts, :pub_date

    execute 'update episodes set published_at = published where published is not null and published > published_at'
    execute 'update episodes set updated_at = updated where updated is not null and updated > updated_at'
    remove_column :episodes, :released_at
    remove_column :episodes, :published
    remove_column :episodes, :updated
  end

  def down
    add_column :podcasts, :last_build_date, :datetime
    add_column :podcasts, :pub_date, :datetime
    execute 'update podcasts set last_build_date = updated_at, pub_date = published_at'

    add_column :episodes, :released_at, :datetime
    add_column :episodes, :published, :datetime
    add_column :episodes, :updated, :datetime
    execute 'update episodes set published = published_at, updated = updated_at'
  end
end
