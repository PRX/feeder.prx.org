class AddCopyrightToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :copyright, :string
  end
end
