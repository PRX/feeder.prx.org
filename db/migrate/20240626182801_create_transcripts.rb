class CreateTranscripts < ActiveRecord::Migration[7.0]
  def change
    create_table :transcripts do |t|
      t.references :episode, index: true
      t.integer :status
      t.string :guid, index: {unique: true}
      t.string :url
      t.string :original_url
      t.string :mime_type
      t.integer :file_size
      t.string :format
      t.timestamps
    end
  end
end
