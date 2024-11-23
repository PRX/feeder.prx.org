class NewFileUploadedState < ActiveRecord::Migration[7.2]
  def change
    add_column :apple_episode_delivery_statuses, :uploaded, :boolean, default: false

    # Set the new column to match the delivered column
    execute(<<~SQL
      UPDATE apple_episode_delivery_statuses
      SET uploaded = delivered
    SQL
           )
  end
end
