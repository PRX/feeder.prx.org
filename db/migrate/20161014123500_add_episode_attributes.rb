class AddEpisodeAttributes < ActiveRecord::Migration
  def change
    add_column :episodes, :url, :string
    add_column :episodes, :author_name, :string
    add_column :episodes, :author_email, :string
    add_column :episodes, :title, :text
    add_column :episodes, :subtitle, :text
    add_column :episodes, :content, :text
    add_column :episodes, :summary, :text
    add_column :episodes, :published, :datetime
    add_column :episodes, :updated, :datetime
    add_column :episodes, :image_url, :string
    add_column :episodes, :explicit, :string
    add_column :episodes, :keywords, :text
    add_column :episodes, :description, :text
    add_column :episodes, :categories, :text
    add_column :episodes, :block, :boolean
    add_column :episodes, :is_closed_captioned, :boolean
    add_column :episodes, :position, :integer
    add_column :episodes, :feedburner_orig_link, :string
    add_column :episodes, :feedburner_orig_enclosure_link, :string
    add_column :episodes, :is_perma_link, :boolean
  end
end
