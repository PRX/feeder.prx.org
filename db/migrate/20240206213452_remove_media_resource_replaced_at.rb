class RemoveMediaResourceReplacedAt < ActiveRecord::Migration[7.0]
  def change
    remove_column :media_resources, :replaced_at, :timestamp
  end
end
