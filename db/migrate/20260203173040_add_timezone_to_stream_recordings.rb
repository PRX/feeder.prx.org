class AddTimezoneToStreamRecordings < ActiveRecord::Migration[7.2]
  def change
    add_column :stream_recordings, :timezone, :string
  end
end
