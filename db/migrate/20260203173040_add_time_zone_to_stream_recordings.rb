class AddTimeZoneToStreamRecordings < ActiveRecord::Migration[7.2]
  def change
    add_column :stream_recordings, :time_zone, :string
  end
end
