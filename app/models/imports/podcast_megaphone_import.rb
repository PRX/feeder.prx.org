require "feedjira"

class PodcastMegaphoneImport < PodcastImport
  store :config, accessors: [:megaphone_podcast_id, :megaphone_podcast_json, :override_enclosures, :new_episodes_only, :published_only], coder: JSON

  attr_writer :megaphone_feed

  def set_defaults
    @megaphone_episodes = []
    @megaphone_feed = nil
    self.new_episodes_only ||= false
    self.override_enclosures ||= false
    self.published_only ||= false
    super
  end

  def import!
    status_started!

    create_or_update_podcast!
    create_or_update_episode_imports!

    if episode_imports.any?
      status_importing!
    else
      status_complete!
    end
  rescue => err
    reset_podcast if podcast.invalid?
    status_error!
    unlock_podcast_later!
    raise err
  end

  def create_or_update_podcast!
    podcast_hash = megaphone_podcast.as_json.with_indifferent_access.slice(Megaphone::Podcast::ALL_ATTRIBUTES)
    self.megaphone_podcast_json = podcast_hash

    podcast.assign_attributes(**build_podcast_attributes)
    if podcast.invalid?
      podcast.restore_attributes(podcast.errors.attribute_names)
    end
    podcast.save!
    update_images

    megaphone_podcast.update_sync_log

    podcast
  end

  def megaphone_podcast(mf = megaphone_feed, mpid = megaphone_podcast_id)
    @megaphone_podcast ||= Megaphone::Podcast.find_megaphone_podcast(mf, mpid)
  end

  def update_images
    default_feed = podcast.default_feed

    if megaphone_podcast.background_image_file_url.present?
      default_feed.itunes_image = megaphone_podcast.background_image_file_url
      default_feed.save!
    end

    default_feed.itunes_images.reset
    default_feed.feed_images.reset

    default_feed.copy_media
  end

  def build_podcast_attributes
    podcast_attributes = {}
    podcast_attributes[:title] = megaphone_podcast.title
    podcast_attributes[:subtitle] = megaphone_podcast.subtitle || megaphone_podcast.summary || megaphone_podcast.title
    podcast_attributes[:description] = megaphone_podcast.summary
    podcast_attributes[:itunes_categories] = parse_itunes_categories(megaphone_podcast.itunes_categories)
    podcast_attributes[:language] = podcast_language(megaphone_podcast.language)
    podcast_attributes[:link] = megaphone_podcast.link
    podcast_attributes[:copyright] = megaphone_podcast.copyright
    podcast_attributes[:author_name] = megaphone_podcast.author
    podcast_attributes[:explicit] = megaphone_podcast.explicit
    podcast_attributes[:owner_name] = megaphone_podcast.owner_name
    podcast_attributes[:owner_email] = megaphone_podcast.owner_email
    podcast_attributes[:display_episodes_count] = megaphone_podcast.episode_limit
    podcast_attributes[:itunes_type] = megaphone_podcast.podcast_type

    podcast_attributes
  end

  def podcast_language(language)
    if language == "en"
      "en-us"
    elsif language == "es"
      "es-mx"
    else
      language
    end
  end

  def megaphone_feed
    @megaphone_feed ||= Feeds::MegaphoneFeed.where(podcast: podcast).first
  end

  # returns a paged collection of episodes
  def megaphone_episodes
    @megaphone_episodes ||= megaphone_podcast.episodes(published_only)
  end

  def create_or_update_episode_imports!
    update(feed_episode_count: megaphone_episodes.count)

    # optionally skip existing
    existing_guids = Episode.where(podcast_id: podcast_id).map(&:item_guid) if new_episodes_only

    # cleanup existing dups - they may be recreated later
    episode_imports.status_duplicate.destroy_all

    # we'll update existing episode imports, instead of creating new
    existing = episode_imports.map { |ei| [ei.guid, ei] }.to_h

    # top-most guids win, others are marked dup
    guids = []
    to_import = []
    megaphone_episodes.each do |megaphone_episode|
      guid = megaphone_episode.item_guid
      entry_hash = megaphone_episode.to_h

      if new_episodes_only && existing_guids.include?(guid)
        next
      elsif guids.include?(guid)
        episode_imports.create!(guid: guid, entry: entry_hash, status: :duplicate, type: "EpisodeMegaphoneImport")
      else
        guids << guid
        ei = existing[guid] || episode_imports.build(type: "EpisodeMegaphoneImport")
        ei.guid = guid
        ei.entry = entry_hash
        ei.save!
        to_import << ei
      end
    end
  end

  def import_existing
    !new_episodes_only
  end

  def import_existing=(val)
    self.new_episodes_only = !ActiveModel::Type::Boolean.new.cast(val)
  end

  def import_drafts
    !published_only
  end

  def import_drafts=(val)
    self.published_only = !ActiveModel::Type::Boolean.new.cast(val)
  end
end
