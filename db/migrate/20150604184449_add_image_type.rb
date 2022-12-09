class AddImageType < ActiveRecord::Migration[4.2]
  def change
    add_column :feed_images, :format, :string
    add_column :feed_images, :size, :integer

    add_column :itunes_images, :format, :string
    add_column :itunes_images, :width, :integer
    add_column :itunes_images, :height, :integer
    add_column :itunes_images, :size, :integer
  end
end
