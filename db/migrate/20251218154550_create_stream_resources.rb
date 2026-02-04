class CreateStreamResources < ActiveRecord::Migration[7.2]
  def change
    create_table :stream_resources do |t|
      t.references :stream_recording, index: true, foreign_key: true

      # timeframe we were trying to capture, vs actually recorded
      t.timestamp :start_at, index: true
      t.timestamp :end_at, index: true
      t.timestamp :actual_start_at
      t.timestamp :actual_end_at

      # file locations
      t.string :guid
      t.string :url
      t.string :original_url

      # metadata
      t.string :status
      t.string :mime_type
      t.integer :file_size
      t.integer :bit_rate
      t.decimal :sample_rate
      t.integer :channels
      t.decimal :duration

      t.timestamps
      t.timestamp :deleted_at
    end
  end
end
