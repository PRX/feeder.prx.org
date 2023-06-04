class CreatePublishingAttempts < ActiveRecord::Migration[7.0]
  def change
    create_table :publishing_attempts do |t|
      t.references :podcast, null: false, foreign_key: true
      t.references :publishing_queue_item, null: false, foreign_key: true
      t.boolean :complete, null: false, default: false

      t.datetime :created_at, null: false
    end

    add_index :publishing_attempts, [:podcast_id, :publishing_queue_item_id], unique: true, name: "index_publishing_attempts_on_podcast_id_and_queue_item_id"
    add_index :publishing_attempts, [:podcast_id, :complete]
  end
end
