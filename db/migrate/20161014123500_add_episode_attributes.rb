class AddEpisodeAttributes < ActiveRecord::Migration[4.2]
  def up
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

    Episode.where(prx_uri: nil, title: nil).each do |e|
      EpisodeEntryHandler.new(e).update_from_overrides
      puts "saving #{e.id}..."
      e.save!
    end
  end

  def down
    remove_column :episodes, :url
    remove_column :episodes, :author_name
    remove_column :episodes, :author_email
    remove_column :episodes, :title
    remove_column :episodes, :subtitle
    remove_column :episodes, :content
    remove_column :episodes, :summary
    remove_column :episodes, :published
    remove_column :episodes, :updated
    remove_column :episodes, :image_url
    remove_column :episodes, :explicit
    remove_column :episodes, :keywords
    remove_column :episodes, :description
    remove_column :episodes, :categories
    remove_column :episodes, :block
    remove_column :episodes, :is_closed_captioned
    remove_column :episodes, :position
    remove_column :episodes, :feedburner_orig_link
    remove_column :episodes, :feedburner_orig_enclosure_link
    remove_column :episodes, :is_perma_link
  end
end
