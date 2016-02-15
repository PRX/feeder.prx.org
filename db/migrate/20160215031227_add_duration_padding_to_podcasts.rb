class AddDurationPaddingToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :duration_padding, :decimal
  end
end
