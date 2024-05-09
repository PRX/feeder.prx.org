class RemoveKeywords < ActiveRecord::Migration[7.0]
  def decode(str)
    if str.blank?
      []
    elsif str.is_a?(Array)
      str
    else
      ActiveSupport::JSON.decode(str)
    end
  end

  def up
    add_column :podcasts, :categories_tmp, :string, array: true
    add_column :episodes, :categories_tmp, :string, array: true
    add_index :podcasts, :categories_tmp, using: "gin"
    add_index :episodes, :categories_tmp, using: "gin"

    pod_count = 0
    Podcast.where("categories != '[]' OR keywords != '[]'").find_each do |p|
      pod_count += 1

      # NOTE: for some reason, podcast keywords are comma-separated strings
      cats = decode(p.categories)
      keys = decode(p.keywords).map { |k| k.split(",").map(&:strip) }.flatten

      ActiveRecord::Base.logger.silence do
        p.update_column :categories_tmp, (cats + keys).uniq.reject(&:blank?)
      end
    end
    Rails.logger.info("combined categories/keywords for #{pod_count} podcasts")

    ep_count = 0
    Episode.where("categories != '[]' OR keywords != '[]'").find_each do |e|
      ep_count += 1

      cats = decode(e.categories)
      keys = decode(e.keywords)

      ActiveRecord::Base.logger.silence do
        e.update_column :categories_tmp, (cats + keys).uniq.reject(&:blank?)
      end
    end
    Rails.logger.info("combined categories/keywords for #{ep_count} episodes")

    remove_column :podcasts, :categories
    remove_column :podcasts, :keywords
    rename_column :podcasts, :categories_tmp, :categories
    remove_column :episodes, :categories
    remove_column :episodes, :keywords
    rename_column :episodes, :categories_tmp, :categories
  end

  def down
    add_column :podcasts, :categories_tmp, :text
    add_column :podcasts, :keywords, :text
    add_column :episodes, :categories_tmp, :text
    add_column :episodes, :keywords, :text

    Podcast.where("ARRAY_LENGTH(categories, 1) > 0").find_each do |p|
      ActiveRecord::Base.logger.silence do
        p.update_column :categories_tmp, p.categories.to_json
      end
    end

    Episode.where("ARRAY_LENGTH(categories, 1) > 0").find_each do |e|
      ActiveRecord::Base.logger.silence do
        e.update_column :categories_tmp, e.categories.to_json
      end
    end

    remove_column :podcasts, :categories
    rename_column :podcasts, :categories_tmp, :categories
    remove_column :episodes, :categories
    rename_column :episodes, :categories_tmp, :categories
  end
end
