class FixupImages < ActiveRecord::Migration[7.0]
  def change
    %i[episode_images feed_images itunes_images].each do |tbl|
      add_column tbl, :alt_text, :string
      add_column tbl, :caption, :string
      add_column tbl, :credit, :string

      # these are all blank, and not useful in the RSS
      remove_column tbl, :title, :string
      remove_column tbl, :description, :string
      remove_column tbl, :link, :string
    end
  end
end
