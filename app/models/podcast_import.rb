# encoding: utf-8

require 'prx_access'
require 'announce'
require 'addressable/uri'
require 'feedjira'
require 'itunes_category_validator'
require 'loofah'
require 'hash_serializer'

class PodcastImport < BaseModel
  include ImportUtils

  serialize :config, HashSerializer

  attr_accessor :feed, :templates, :podcast, :distribution

  belongs_to :user, -> { with_deleted }
  belongs_to :account, -> { with_deleted }
  belongs_to :series, -> { with_deleted }

  has_many :episode_imports, dependent: :destroy

  before_validation :set_defaults, on: :create

  validates :user_id, :account_id, :url, presence: true

  def config_url=(config_url)
    c_url = Addressable::URI.parse(config_url)
    response = connection(c_url).get(c_url.path, c_url.query_values)
    self.config = ActiveSupport::JSON.decode(response.body).try(:with_indifferent_access)
  end

  def set_defaults
    self.status ||= 'created'
    self.config ||= {
      audio: {},            # map of guids to array of audio file urls
      episodes_only: false  # indicates if podcast and series should be updated
    }
  end

  def update_status!
    return unless episode_imports.count > 0
    if episode_imports.all? { |e| e.status == 'complete' }
      update_attributes!(status: 'complete')
    elsif episode_imports.any? { |e| e.status == 'failed' }
      update_attributes!(status: 'failed')
    end
  end

  def retry!
    update_attributes(status: 'retrying')
    import_later
  end

  def import_later
    PodcastImportJob.perform_later self
  end

  def import
    update_attributes!(status: 'started')

    # Request the RSS feed
    get_feed
    update_attributes!(status: 'feed retrieved')

    # Create the series
    create_or_update_series!
    update_attributes!(status: 'series created')

    # Update podcast attributes
    create_or_update_podcast!
    update_attributes!(status: 'podcast created')

    # Create the episodes
    update_attributes!(status: 'importing')
    create_or_update_episode_imports!
  rescue StandardError => err
    update_attributes(status: 'failed')
    raise err
  end

  def entry_audio_files(entry)
    if config[:audio] && config[:audio][entry[:entry_id]]
      { files: (config[:audio][entry[:entry_id]] || []) }
    elsif enclosure = enclosure_url(entry)
      { files: [enclosure] }
    end
  end

  def create_or_update_episode_imports!
    feed.entries.map do |entry|
      entry_hash = feed_entry_to_hash(entry)
      audio_files = entry_audio_files(entry_hash)
      get_or_create_template(audio_files, entry_hash['enclosure'].type)
      episode_import = create_or_update_episode_import!(entry_hash, audio_files)
      episode_import.import_later
    end
  end

  def feed_entry_to_hash(entry)
    entry
      .to_h
      .with_indifferent_access
      .transform_values { |x| x.is_a?(String) ? remove_utf8_4byte(x) : x }
  end

  def create_or_update_episode_import!(entry, audio_files)
    if ei = episode_imports.where(guid: entry[:entry_id]).first
      ei.update_attributes!(entry: entry, audio: audio_files)
    else
      ei = episode_imports.create(
        guid: entry[:entry_id],
        entry: entry,
        audio: audio_files
      )
    end
    ei
  end

  def get_feed
    response = connection.get(uri.path, uri.query_values)
    podcast_feed = Feedjira::Feed.parse(response.body)
    validate_feed(podcast_feed)
    self.feed = podcast_feed
  end

  def validate_feed(podcast_feed)
    if !podcast_feed.is_a?(Feedjira::Parser::Podcast)
      parser = podcast_feed.class.name.demodulize.underscore.humanize rescue ''
      raise "Failed to retrieve #{url}, not a podcast feed: #{parser}"
    end
  end

  def feed_description(feed)
    result = [feed.itunes_summary, feed.description].find { |d| !d.blank? }
    clean_text(result)
  end

  def create_or_update_series!(feed = self.feed)
    if config[:episodes_only]
      raise "No series for import of episodes only" if !series
      return series
    end

    series_attributes = {
      app_version: PRX::APP_VERSION,
      account: account,
      title: clean_string(feed.title),
      short_description: clean_string(podcast_short_desc(feed)),
      description_html: feed_description(feed)
    }

    if series
      series.update_attributes!(series_attributes)
    else
      self.series = create_series!(series_attributes)
      save!
    end

    if !podcast_distribution
      self.distribution = Distributions::PodcastDistribution.create!(distributable: series)
    end

    new_images = update_images(feed)

    series.save!

    new_images.each { |i| announce_image(i) }

    series
  end

  def update_images(feed)
    [[Image::PROFILE, feed.itunes_image], [Image::THUMBNAIL, feed.image.try(:url)]].map do |p, u|
      update_image(p, u)
    end.flatten
  end

  def update_image(purpose, image_url)
    if image_url.blank?
      series.images.where(purpose: purpose).destroy_all
      return []
    end

    to_destroy = []
    to_insert = []

    existing_image = series.images.send(purpose)
    if existing_image && !files_match?(existing_image, image_url)
      to_destroy << existing_image
      existing_image = nil
    end

    if !existing_image
      to_insert << series.images.build(upload: clean_string(image_url), purpose: purpose)
    end

    story.images.destroy(to_destroy) if to_destroy.size > 0

    to_insert
  end

  def podcast_distribution
    self.distribution ||= series.distributions.where(type: 'Distributions::PodcastDistribution').first
  end

  def create_or_update_podcast!
    if config[:episodes_only]
      raise "No podcast distribution for import of episodes only" if !podcast_distribution
      raise "No podcast distribution url for import of episodes only" if !podcast_distribution.url
      self.podcast = podcast_distribution.get_podcast
      raise "No podcast for import of episodes only" if !podcast
      return podcast
    end

    podcast_attributes = {}
    %w(copyright language update_frequency update_period).each do |atr|
      podcast_attributes[atr.to_sym] = clean_string(feed.send(atr))
    end

    podcast_attributes[:summary] = clean_text(feed.itunes_summary)
    podcast_attributes[:link] = clean_string(feed.url)
    podcast_attributes[:explicit] = explicit(feed.itunes_explicit)
    podcast_attributes[:new_feed_url] = clean_string(feed.itunes_new_feed_url)
    podcast_attributes[:enclosure_prefix] ||= enclosure_prefix(feed.entries.first)
    podcast_attributes[:feedburner_url] ||= feedburner_url(feed.feedburner_name)
    podcast_attributes[:url] ||= feedburner_url(feed.feedburner_name)

    podcast_attributes[:author] = person(feed.itunes_author)
    podcast_attributes[:managing_editor] = person(feed.managing_editor)
    podcast_attributes[:owner] = owner(feed.itunes_owners)

    podcast_attributes[:itunes_categories] = parse_itunes_categories(feed)
    podcast_attributes[:categories] = parse_categories(feed)
    podcast_attributes[:complete] = (clean_string(feed.itunes_complete) == 'yes')
    podcast_attributes[:copyright] ||= clean_string(feed.media_copyright)
    podcast_attributes[:keywords] = parse_keywords(feed)
    podcast_attributes[:serial_order] = feed.itunes_type && !!feed.itunes_type.match(/serial/i)

    self.podcast = podcast_distribution.create_or_update_podcast!(podcast_attributes)
    podcast
  end

  def enclosure_prefix(podcast_item)
    prefix = ''
    link = [podcast_item.feedburner_orig_enclosure_link,
            podcast_item.enclosure.try(:url),
            podcast_item.media_contents.first.try(:url)].find do |url|
              url.try(:match, /podtrac/) || url.try(:match, /blubrry/)
            end
    if scheme = link.try(:match, /^https?:\/\//)
      prefix += scheme.to_s
    end
    if podtrac = link.try(:match, /\/(\w+\.podtrac.com\/.+?\.mp3\/)/)
      prefix += podtrac[1]
    end
    if blubrry = link.try(:match, /\/(media\.blubrry\.com\/[^\/]+\/)/)
      prefix += blubrry[1]
    end
    prefix
  end

  def feedburner_url(fb_name)
    fb_name ? "http://feeds.feedburner.com/#{clean_string(fb_name)}" : nil
  end

  def owner(itunes_owners)
    if o = itunes_owners.try(:first)
      { name: clean_string(o.name), email: clean_string(o.email) }
    end
  end

  def parse_itunes_categories(feed)
    itunes_cats = {}
    Array(feed.itunes_categories).map(&:strip).select { |c| !c.blank? }.each do |cat|
      if ITunesCategoryValidator.category?(cat)
        itunes_cats[cat] ||= []
      elsif parent_cat = ITunesCategoryValidator.subcategory?(cat)
        itunes_cats[parent_cat] ||= []
        itunes_cats[parent_cat] << cat
      end
    end

    itunes_cats.keys.map { |n| { name: n, subcategories: itunes_cats[n] } }
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

  def get_or_create_template(audio_files, enclosure_type = nil)
    num_segments = [audio_files[:files].count, 1].max
    template = nil
    contains_video = enclosure_type && enclosure_type.starts_with?('video/')
    content_type = contains_video ? AudioFile::VIDEO_CONTENT_TYPE : AudioFile::MP3_CONTENT_TYPE

    self.series.with_lock do
      template = series.audio_version_templates.
                 where(segment_count: num_segments, content_type: content_type).first
      if !template
        template = series.audio_version_templates.create!(
          label: podcast_label(contains_video, num_segments),
          content_type: content_type,
          segment_count: num_segments,
          promos: false,
          length_minimum: 0,
          length_maximum: 0
        )

        num_segments.times do |x|
          num = x + 1
          template.audio_file_templates.create!(
            position: num,
            label: "Segment #{num}",
            length_minimum: 0,
            length_maximum: 0
          )
        end

        podcast_distribution.distribution_templates.create!(
          distribution: podcast_distribution,
          audio_version_template: template
        )
      end
    end

    template
  end

  def podcast_label(contains_video, num_segments)
    label = contains_video ? 'Podcast Video' : 'Podcast Audio'
    label += " #{num_segments} #{'segment'.pluralize(num_segments)}"
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
      c.headers[:user_agent] = 'PRX CMS FeedValidator'
    end
  end

  def self.policy_class
    AccountablePolicy
  end
end
