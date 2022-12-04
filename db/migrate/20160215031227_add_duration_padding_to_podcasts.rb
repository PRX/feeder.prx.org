class AddDurationPaddingToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :duration_padding, :decimal
  end
end
