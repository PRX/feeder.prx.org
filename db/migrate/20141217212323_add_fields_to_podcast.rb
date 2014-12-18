class AddFieldsToPodcast < ActiveRecord::Migration
  def change
    add_column :podcasts, :author, :string
    add_column :podcasts, :owner_name, :string
    add_column :podcasts, :owner_email, :string
  end
end
