class CreatePublishingLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :publishing_logs do |t|
      t.references :podcast, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    add_index :publishing_logs, [:podcast_id, :created_at]
  end
end
