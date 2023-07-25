require "loofah"
require "hash_serializer"

class PodcastImport < ApplicationRecord
  include ImportUtils

  serialize :config, HashSerializer

  attr_accessor :feed, :feed_raw_doc, :templates, :feed_source

  belongs_to :podcast, -> { with_deleted }, touch: true, optional: true, autosave: true
  has_many :episode_imports, -> { where(has_duplicate_guid: false).includes(:podcast_import) }, dependent: :destroy

  before_validation :set_defaults, on: :create

  validates :url, presence: true

  enum :status, {
    audio_saved: AUDIO_SAVED,
    complete: COMPLETE,
    created: CREATED,
    saved: SAVED,
    failed: FAILED,
    feed_retrieved: FEED_RETRIEVED,
    importing: IMPORTING,
    retrying: RETRYING,
    started: STARTED
  }, prefix: true

  def episode_import_placeholders
    EpisodeImport.where(podcast_import_id: id).having_duplicate_guids
  end

  def config_url=(config_url)
    c_url = Addressable::URI.parse(config_url)
    response = connection(c_url).get(c_url.path, c_url.query_values)
    self.config = ActiveSupport::JSON.decode(response.body).try(:with_indifferent_access)
  end

  def set_defaults
    self.status ||= CREATED
    self.config ||= {
      audio: {},            # map of guids to array of audio file urls
      episodes_only: false  # indicates if podcast should be updated
    }
  end

  def episode_importing_count
    feed_episode_count - episode_import_placeholders.count
  end

  def remaining_import_count
    if feed_episode_count.present?
      feed_episode_count - episode_imports.finished.count
    end
  end

  def status
    return super unless episode_imports.count > 0
    return super if episode_importing_count > episode_imports.count

    if complete?
      status_complete!
      COMPLETE
    elsif finished? && some_failed?
      status_failed!
      FAILED
    else
      super
    end
  end

  def finished?
    return false unless episode_imports.count == episode_importing_count
    episode_imports.all? do |e|
      e.finished?
    end
  end

  def complete?
    return false unless episode_imports.count == episode_importing_count
    episode_imports.all? { |e| e.status_complete? }
  end

  def some_failed?
    episode_imports.any? { |e| e.status_failed? }
  end

  def retry!
    status_retrying!
    import_later
  end

  def import_later(import_podcast = true)
    PodcastImportJob.perform_later(self, import_podcast)
  end

  def import_podcast!
    status_started!

    # Request the RSS feed
    get_feed
    status_feed_retrieved!

    # Create the podcast
    create_or_update_podcast!
    status_created!
  rescue => err
    status_failed!
    raise err
  end

  def import_episodes!
    # Request the RSS feed again
    get_feed

    # Update podcast attributes
    create_or_update_podcast!
    status_created!

    # Create the episodes
    create_or_update_episode_imports!
    status_importing!
  rescue => err
    Rails.logger.error ([err.message] + err.backtrace).join($/)
    status_failed!
    raise err
  end

  def import
    import_podcast!
    import_episodes!
  end

  def create_or_update_episode_imports!
    update(feed_episode_count: feed.entries.count)

    feed_entries, entries_with_dupe_guids = parse_feed_entries_for_dupe_guids

    episode_imports.having_duplicate_guids.destroy_all

    created_imports = feed_entries.map do |entry|
      create_or_update_episode_import!(entry)
    end

    enqueue_episode_import_jobs(created_imports)

    created_imports += entries_with_dupe_guids.map do |entry|
      create_or_update_episode_import!(entry, true)
    end

    created_imports
  end

  def enqueue_episode_import_jobs(created_imports)
    created_imports.map do |ei|
      EpisodeImportJob.perform_later(ei)
    end
  end

  def feed_entry_to_hash(entry)
    entry
      .to_h
      .as_json
      .with_indifferent_access
  end

  def create_or_update_episode_import!(entry, has_duplicate_guid = false)
    entry_hash = feed_entry_to_hash(entry)

    if (ei = episode_imports.where(guid: entry_hash[:entry_id]).first)
      ei.update!(entry: entry_hash, has_duplicate_guid: has_duplicate_guid)
    else
      ei = episode_imports.create!(
        guid: entry_hash[:entry_id],
        entry: entry_hash,
        has_duplicate_guid: has_duplicate_guid
      )
    end
    ei
  end

  def get_feed
    response = connection.get(uri.path, uri.query_values)
    self.feed_raw_doc = response.body
    podcast_feed = Feedjira.parse(feed_raw_doc)
    validate_feed(podcast_feed)
    self.feed = podcast_feed
  end

  def validate_feed(podcast_feed)
    if !podcast_feed.is_a?(Feedjira::Parser::Podcast)
      parser = begin
        podcast_feed.class.name.demodulize.underscore.humanize
      rescue
        ""
      end
      raise "Failed to retrieve #{url}, not a podcast feed: #{parser}"
    end
  end

  def feed_description(feed)
    result = [feed.itunes_summary, feed.description].find { |d| !d.blank? }
    clean_text(result)
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
    podcast_attributes[:feedburner_url] ||= feedburner_url(feed.feedburner_name)
    podcast_attributes[:url] ||= feedburner_url(feed.feedburner_name)

    podcast_attributes[:author] = person(feed.itunes_author)
    podcast_attributes[:managing_editor] = person(feed.managing_editor)

    owner = owner(feed.itunes_owners)
    podcast_attributes[:owner_name] = owner[:name]
    podcast_attributes[:owner_email] = owner[:email]

    podcast_attributes[:itunes_categories] = parse_itunes_categories(feed)
    podcast_attributes[:categories] = parse_categories(feed)
    podcast_attributes[:complete] = (clean_string(feed.itunes_complete) == "yes")
    podcast_attributes[:copyright] ||= clean_string(feed.media_copyright)
    podcast_attributes[:keywords] = parse_keywords(feed)
    podcast_attributes[:serial_order] = feed.itunes_type && !!feed.itunes_type.match(/serial/i)
    podcast_attributes[:locked] = true # won't publish feed until this is set to false

    podcast_attributes[:title] = clean_string(feed.title)
    podcast_attributes[:subtitle] = clean_string(podcast_short_desc(feed))
    podcast_attributes[:description] = feed_description(feed)

    podcast_attributes
  end

  def create_or_update_podcast!
    if config[:episodes_only]
      raise "No podcast for import of episodes only" unless podcast&.persisted?
      raise "No podcast for import of episodes only" if !podcast
      return podcast
    end

    self.podcast ||= Podcast.new
    podcast.assign_attributes(**build_podcast_attributes)
    update!(podcast: podcast)

    update_images(feed)

    podcast
  end

  def enclosure_prefix(podcast_item)
    prefix = ""
    link = [podcast_item.feedburner_orig_enclosure_link,
      podcast_item.enclosure.try(:url),
      podcast_item.media_contents.first.try(:url)].find do |url|
      url.try(:match, /podtrac/) || url.try(:match, /blubrry/)
    end
    if (scheme = link.try(:match, /^https?:\/\//))
      prefix += scheme.to_s
    end
    if (podtrac = link.try(:match, /\/(\w+\.podtrac.com\/.+?\.mp3\/)/))
      prefix += podtrac[1]
    end
    if (blubrry = link.try(:match, /\/(media\.blubrry\.com\/[^\/]+\/)/))
      prefix += blubrry[1]
    end
    prefix
  end

  def feedburner_url(fb_name)
    fb_name ? "https://feeds.feedburner.com/#{clean_string(fb_name)}" : nil
  end

  def owner(itunes_owners)
    if (o = itunes_owners.try(:first))
      {name: clean_string(o.name), email: clean_string(o.email)}
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

  def parse_categories(feed)
    mcat = Array(feed.media_categories).map(&:strip)
    rcat = Array(feed.categories).map(&:strip)
    (mcat + rcat).compact.uniq
  end

  def parse_keywords(feed)
    ikey = Array(feed.itunes_keywords).map(&:strip)
    mkey = Array(feed.media_keywords).map(&:strip)
    (ikey + mkey).compact.uniq
  end

  def podcast_label(contains_video, num_segments)
    label = contains_video ? "Podcast Video" : "Podcast Audio"
    label += " #{num_segments} #{"segment".pluralize(num_segments)}"
    label
  end

  def podcast_short_desc(item)
    [item.itunes_subtitle, item.description, item.title].find do |field|
      !field.blank? && field.split.length < 50
    end
  end

  def uri
    @uri ||= Addressable::URI.parse(url)
  end

  def connection(u = uri)
    conn_uri = "#{u.scheme}://#{u.host}:#{u.port}"
    Faraday.new(conn_uri) { |stack| stack.adapter :excon }.tap do |c|
      c.headers[:user_agent] = "PRX CMS FeedValidator"
    end
  end

  def parse_feed_entries_for_dupe_guids
    sorted_entries = feed.entries.sort_by(&:entry_id)

    dupped_entries = []
    good_entries = []
    duplicate_run = []

    process_duplicate_run = lambda do
      if duplicate_run.length > 1
        dupped_entries += duplicate_run
      else
        good_entries += duplicate_run
      end
      duplicate_run = []
    end

    sorted_entries.each do |entry|
      if duplicate_run.last.present? && (entry.entry_id != duplicate_run.last.entry_id)
        process_duplicate_run.call
      end
      duplicate_run.push(entry)
    end
    process_duplicate_run.call

    [good_entries, dupped_entries]
  end
end
