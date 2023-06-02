class CreatePublishingAttempts < ActiveRecord::Migration[7.0]
  def change
    create_table :publishing_attempts do |t|
      t.references :podcast, null: false, foreign_key: true
      t.references :publishing_log, null: false, foreign_key: true
      t.boolean :complete, null: false, default: false

      t.timestamps
    end

    add_index :publishing_attempts, [:podcast_id, :publishing_log_id], unique: true
    add_index :publishing_attempts, [:podcast_id, :complete]
  end
end
