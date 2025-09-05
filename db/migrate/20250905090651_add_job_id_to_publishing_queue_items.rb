class AddJobIdToPublishingQueueItems < ActiveRecord::Migration[7.1]
  def change
    add_column :publishing_queue_items, :job_id, :string
  end
end