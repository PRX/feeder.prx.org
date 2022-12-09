class AddUrlStringToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :url, :string
  end
end
