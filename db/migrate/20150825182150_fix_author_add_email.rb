class FixAuthorAddEmail < ActiveRecord::Migration[4.2]
  def change
    rename_column :podcasts, :author, :author_name
    add_column :podcasts, :author_email, :string
  end
end
