class AddSegmentationToMediaResources < ActiveRecord::Migration[7.0]
  def change
    add_column :media_resources, :segmentation, :text
  end
end
