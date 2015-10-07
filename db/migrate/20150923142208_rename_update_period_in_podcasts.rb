class RenameUpdatePeriodInPodcasts < ActiveRecord::Migration
  def change
    rename_column :podcasts, :update_value, :update_frequency
  end
end
