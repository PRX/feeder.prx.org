class AddMediaStatusAndOriginalUrl < ActiveRecord::Migration
  def change
    add_column :media_resources, :status, :string

    add_column :media_resources, :original_url, :string
    add_index :media_resources, :original_url

    add_column :media_resources, :guid, :string
    add_index :media_resources, :guid, unique: true
  end
end
