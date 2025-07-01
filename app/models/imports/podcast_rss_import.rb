require "feedjira"

class PodcastRssImport < PodcastImport
  store :config, accessors: [:episodes_only, :new_episodes_only, :audio, :channel, :first_entry], coder: JSON

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
    @feed_rss ||= http_get(url)
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

  def channel
    config[:channel] ||= feed.as_json.with_indifferent_access.without(:entries)
  end

  def first_entry
    config[:first_entry] ||= feed.entries.first.to_h.as_json.with_indifferent_access
  end

  def url=(value)
    @feed_rss = nil
    @feed = nil
    self.channel = nil
    self.first_entry = nil
    self.feed_episode_count = nil
    super
  end

  def feed_rss=(value)
    @feed_rss = value
    @feed = nil
    self.channel = nil
    self.first_entry = nil
    self.feed_episode_count = nil
  end

  def validate_rss
    if url.blank?
      errors.add(:url, :blank)
    elsif !HttpUrlValidator.http_url?(url)
      errors.add(:url, :not_http_url)
    elsif feed_episode_count.nil?
      self.feed_episode_count = feed.entries.count
      channel
      first_entry

      if clean_yes_no(channel[:podcast_locked])
        errors.add(:url, :podcast_locked, message: "podcast locked")
      end
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
    reset_podcast if podcast.invalid?
    status_error!
    unlock_podcast_later!
    raise err
  end

  def create_or_update_episode_imports!
    update(feed_episode_count: feed.entries.count)

    # optionally skip existing
    existing_guids = Episode.where(podcast_id: podcast_id).map(&:item_guid) if new_episodes_only

    # cleanup existing dups - they may be recreated later
    episode_imports.status_duplicate.destroy_all

    # we'll update existing episode imports, instead of creating new
    existing = episode_imports.map { |ei| [ei.guid, ei] }.to_h

    # top-most guids win, others are marked dup
    guids = []
    to_import = []
    feed.entries.each do |entry|
      guid = clean_string(entry.entry_id)
      entry_hash = entry.to_h.as_json.with_indifferent_access

      if new_episodes_only && existing_guids.include?(guid)
        next
      elsif guids.include?(guid)
        episode_imports.create!(guid: guid, entry: entry_hash, status: :duplicate)
      else
        guids << guid
        ei = existing[guid] || episode_imports.build
        ei.guid = guid
        ei.entry = entry_hash
        ei.save!
        to_import << ei
      end
    end

    # wait till all are created before starting any jobs
    to_import.each(&:import_later)
  end

  def feed_description
    result = [channel[:description], channel[:itunes_summary]].find { |d| !d.blank? }
    clean_text(result)
  end

  def update_itunes_categories
    default_feed = podcast.default_feed
    default_feed.itunes_categories = parse_itunes_categories
    default_feed.save!
  end

  def update_images
    default_feed = podcast.default_feed

    default_feed.itunes_image = clean_url(channel[:itunes_image]) if channel[:itunes_image].present?
    default_feed.feed_image = clean_url(channel[:image][:url]) if channel[:image].present?
    default_feed.save!

    default_feed.itunes_images.reset
    default_feed.feed_images.reset

    default_feed.copy_media
  end

  def build_podcast_attributes
    podcast_attributes = {}

    %w[copyright language update_frequency update_period].each do |atr|
      podcast_attributes[atr.to_sym] = clean_string(channel[atr])
    end

    podcast_attributes[:link] = clean_url(channel[:url])
    podcast_attributes[:explicit] = explicit(channel[:itunes_explicit], "false")
    podcast_attributes[:new_feed_url] = clean_url(channel[:itunes_new_feed_url])
    podcast_attributes[:enclosure_prefix] ||= enclosure_prefix
    podcast_attributes[:url] ||= clean_url(channel[:feed_url])

    podcast_attributes[:author] = person(channel[:itunes_author])
    podcast_attributes[:managing_editor] = person(channel[:managing_editor])

    podcast_attributes[:owner_name] = owner[:name]
    podcast_attributes[:owner_email] = owner[:email]

    podcast_attributes[:complete] = clean_yes_no(channel[:itunes_complete])
    podcast_attributes[:copyright] ||= clean_string(channel[:media_copyright])
    podcast_attributes[:serial_order] = channel[:itunes_type] && !!channel[:itunes_type].match(/serial/i)
    podcast_attributes[:locked_until] = 10.minutes.from_now

    podcast_attributes[:title] = clean_string(channel[:title])
    podcast_attributes[:subtitle] = clean_string(podcast_short_desc)
    podcast_attributes[:description] = feed_description

    podcast_attributes[:guid] = clean_string(channel[:podcast_guid])
    podcast_attributes[:donation_url] = clean_url(channel[:podcast_funding])

    # categories setter does the work of sanitizing these
    cats = Array(channel[:categories])
    ikeys = (channel[:itunes_keywords] || "").split(",")
    mkeys = (channel[:media_keywords] || "").split(",")
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
    if podcast.invalid?
      podcast.restore_attributes(podcast.errors.attribute_names)
    end
    podcast.save!

    update_itunes_categories
    update_images

    podcast
  end

  def enclosure_prefix
    redirectors = [
      /\/(www|dts)\.podtrac\.com(\/pts)?\/redirect\.mp3\//,
      /\/media\.blubrry\.com\/[^\/]+\//,
      /\/chrt\.fm\/track\/[^\/]+\//,
      /\/chtbl\.com\/track\/[^\/]+\//,
      /\/pdst\.fm\/e\//
    ]

    item = first_entry || {}
    urls = [item[:feedburner_orig_enclosure_link], item[:enclosure].try(:[], :url), item[:media_contents]&.first.try(:[], :url)]
    url = urls.compact.find { |u| redirectors.any? { |r| u.match?(r) } }

    if url.present?
      end_index = redirectors.map { |r| url.index(r) + url[r].length if url.match?(r) }.compact.max
      url[0...end_index]
    end
  end

  def owner
    if (o = channel[:itunes_owners].try(:first))
      {name: clean_string(o[:name]), email: clean_string(o[:email])}.with_indifferent_access
    else
      {}
    end
  end

  def parse_itunes_categories
    itunes_cats = {}
    Array(channel[:itunes_categories]).map(&:strip).select { |c| !c.blank? }.each do |cat|
      if ITunesCategoryValidator.category?(cat)
        itunes_cats[cat] ||= []
      elsif (parent_cat = ITunesCategoryValidator.subcategory?(cat))
        itunes_cats[parent_cat] ||= []
        itunes_cats[parent_cat] << cat
      end
    end

    [itunes_cats.keys.map { |n| ITunesCategory.new(name: n, subcategories: itunes_cats[n]) }.first].compact
  end

  def podcast_short_desc
    [channel[:itunes_subtitle], channel[:description], channel[:title]].find do |field|
      !field.blank? && field.split.length < 50
    end
  end
end
