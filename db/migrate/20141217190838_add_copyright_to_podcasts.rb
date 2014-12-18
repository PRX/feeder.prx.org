class AddCopyrightToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :copyright, :string
  end
end
