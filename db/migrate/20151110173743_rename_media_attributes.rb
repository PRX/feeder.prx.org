class RenameMediaAttributes < ActiveRecord::Migration
  def change
    rename_column :media_resources, :bitrate, :bit_rate
    rename_column :media_resources, :framerate, :frame_rate
    rename_column :media_resources, :samplingrate, :sample_rate
  end
end
