class CreatePublishingPipelineStates < ActiveRecord::Migration[7.0]
  def change
    create_table :publishing_pipeline_states do |t|
      t.references :podcast, null: false, foreign_key: true
      t.references :publishing_queue_item, null: false, foreign_key: true
      t.integer :status, null: false, default: 0

      t.datetime :created_at, null: false
    end

    add_index :publishing_pipeline_states, [:podcast_id, :publishing_queue_item_id, :status], unique: true, name: "index_publishing_pipeline_state_on_podcast_id_and_queue_item_id"
    add_index :publishing_pipeline_states, [:podcast_id, :publishing_queue_item_id, :status], name: "index_publishing_pipeline_state_uniqueness"
  end
end
