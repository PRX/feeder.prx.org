class RenameUpdatePeriodInPodcasts < ActiveRecord::Migration[4.2]
  def change
    rename_column :podcasts, :update_value, :update_frequency
  end
end
