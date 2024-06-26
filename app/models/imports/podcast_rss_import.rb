require "feedjira"

class PodcastRssImport < PodcastImport
  store :config, accessors: [:episodes_only, :new_episodes_only, :audio, :feed_rss], coder: JSON

  has_many :episode_imports, dependent: :destroy, class_name: "EpisodeRssImport", foreign_key: :podcast_import_id

  validate :validate_rss
  validates :url, presence: true, http_url: true

  def set_defaults
    super
    self.episodes_only ||= false
    self.new_episodes_only ||= false
    self.audio ||= {}
  end

  def file_name
    name = File.basename(url).split("?").first
    name.present? ? name : Feed::DEFAULT_FILE_NAME
  end

  def feed_rss
    config[:feed_rss] ||= http_get(url)
  end

  def feed
    @feed ||= begin
      parsed = Feedjira.parse(feed_rss)
      unless parsed.is_a?(Feedjira::Parser::Podcast)
        parser = begin
          parsed.class.name.demodulize.underscore.humanize
        rescue
          ""
        end
        raise "Failed to validate #{url}, not a podcast feed: #{parser}"
      end
      parsed
    end
  end

  def url=(value)
    @feed = nil
    self.feed_rss = nil
    self.feed_episode_count = nil
    super
  end

  def feed_rss=(value)
    @feed = nil
    super
  end

  def validate_rss
    if url.blank?
      errors.add(:url, :blank)
    elsif !HttpUrlValidator.http_url?(url)
      errors.add(:url, :not_http_url)
    else
      self.feed_episode_count = feed.entries.count
    end
  rescue ImportUtils::HttpError
    errors.add(:url, :bad_http_response, message: "bad http response")
  rescue
    errors.add(:url, :invalid_rss, message: "invalid rss")
  end

  def import_metadata
    !episodes_only
  end

  def import_metadata=(val)
    self.episodes_only = !ActiveModel::Type::Boolean.new.cast(val)
  end

  def import_existing
    !new_episodes_only
  end

  def import_existing=(val)
    self.new_episodes_only = !ActiveModel::Type::Boolean.new.cast(val)
  end

  def config_url=(config_url)
    self.config = JSON.parse(http_get(config_url))
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
    status_error!
    unlock_podcast!
    raise err
  end

  def create_or_update_episode_imports!
    update(feed_episode_count: feed.entries.count)

    # optionally skip existing
    existing_guids = Episode.where(podcast_id: podcast_id).map(&:item_guid) if new_episodes_only

    # cleanup existing dups - they may be recreated later
    episode_imports.status_duplicate.destroy_all

    # top-most guids win, others are marked dup
    guids = []
    feed.entries.each do |entry|
      guid = entry.entry_id
      entry_hash = entry.to_h.as_json.with_indifferent_access

      if new_episodes_only && existing_guids.include?(guid)
        next
      elsif guids.include?(guid)
        episode_imports.create!(guid: guid, entry: entry_hash, status: :duplicate)
      else
        guids << guid
        ei = episode_imports.not_status_duplicate.find_by_guid(guid) || episode_imports.build
        ei.guid = guid
        ei.entry = entry_hash
        ei.save!
        ei.import_later
      end
    end
  end

  def feed_description(feed)
    result = [feed.itunes_summary, feed.description].find { |d| !d.blank? }
    clean_text(result)
  end

  def update_itunes_categories(feed)
    default_feed = podcast.default_feed
    default_feed.itunes_categories = parse_itunes_categories(feed)
    default_feed.save!
  end

  def update_images(feed)
    default_feed = podcast.default_feed

    default_feed.itunes_image = feed.itunes_image if feed.itunes_image.present?
    default_feed.feed_image = feed.image.url if feed.image.present?
    default_feed.save!

    default_feed.itunes_images.reset
    default_feed.feed_images.reset

    default_feed.copy_media
  end

  def build_podcast_attributes
    podcast_attributes = {}

    %w[copyright language update_frequency update_period].each do |atr|
      podcast_attributes[atr.to_sym] = clean_string(feed.send(atr))
    end

    podcast_attributes[:summary] = clean_text(feed.itunes_summary)
    podcast_attributes[:link] = clean_string(feed.url)
    podcast_attributes[:explicit] = explicit(feed.itunes_explicit, "false")
    podcast_attributes[:new_feed_url] = clean_string(feed.itunes_new_feed_url)
    podcast_attributes[:enclosure_prefix] ||= enclosure_prefix(feed.entries.first)
    podcast_attributes[:url] ||= clean_string(feed.feed_url)

    podcast_attributes[:author] = person(feed.itunes_author)
    podcast_attributes[:managing_editor] = person(feed.managing_editor)

    owner = owner(feed.itunes_owners)
    podcast_attributes[:owner_name] = owner[:name]
    podcast_attributes[:owner_email] = owner[:email]

    podcast_attributes[:complete] = (clean_string(feed.itunes_complete) == "yes")
    podcast_attributes[:copyright] ||= clean_string(feed.media_copyright)
    podcast_attributes[:serial_order] = feed.itunes_type && !!feed.itunes_type.match(/serial/i)
    podcast_attributes[:locked] = true # won't publish feed until this is set to false

    podcast_attributes[:title] = clean_string(feed.title)
    podcast_attributes[:subtitle] = clean_string(podcast_short_desc(feed))
    podcast_attributes[:description] = feed_description(feed)

    # categories setter does the work of sanitizing these
    cats = Array(feed.categories)
    ikeys = (feed.itunes_keywords || "").split(",")
    mkeys = (feed.media_keywords || "").split(",")
    podcast_attributes[:categories] = cats + ikeys + mkeys

    podcast_attributes
  end

  def create_or_update_podcast!
    if episodes_only
      raise "No podcast for import of episodes only" unless podcast&.persisted?
      raise "No podcast for import of episodes only" if !podcast
      return podcast
    end

    self.podcast ||= Podcast.new
    podcast.assign_attributes(**build_podcast_attributes)
    update!(podcast: podcast)

    update_itunes_categories(feed)
    update_images(feed)

    podcast
  end

  def enclosure_prefix(item)
    redirectors = [
      /\/(www|dts)\.podtrac\.com(\/pts)?\/redirect\.mp3\//,
      /\/media\.blubrry\.com\/[^\/]+\//,
      /\/chrt\.fm\/track\/[^\/]+\//,
      /\/chtbl\.com\/track\/[^\/]+\//,
      /\/pdst\.fm\/e\//
    ]

    urls = [item.feedburner_orig_enclosure_link, item.enclosure.try(:url), item.media_contents.first.try(:url)]
    url = urls.compact.find { |u| redirectors.any? { |r| u.match?(r) } }

    if url.present?
      end_index = redirectors.map { |r| url.index(r) + url[r].length if url.match?(r) }.compact.max
      url[0...end_index]
    end
  end

  def owner(itunes_owners)
    if (o = itunes_owners.try(:first))
      {name: clean_string(o.name), email: clean_string(o.email)}.with_indifferent_access
    else
      {}
    end
  end

  def parse_itunes_categories(feed)
    itunes_cats = {}
    Array(feed.itunes_categories).map(&:strip).select { |c| !c.blank? }.each do |cat|
      if ITunesCategoryValidator.category?(cat)
        itunes_cats[cat] ||= []
      elsif (parent_cat = ITunesCategoryValidator.subcategory?(cat))
        itunes_cats[parent_cat] ||= []
        itunes_cats[parent_cat] << cat
      end
    end

    [itunes_cats.keys.map { |n| ITunesCategory.new(name: n, subcategories: itunes_cats[n]) }.first].compact
  end

  def podcast_short_desc(item)
    [item.itunes_subtitle, item.description, item.title].find do |field|
      !field.blank? && field.split.length < 50
    end
  end
end
