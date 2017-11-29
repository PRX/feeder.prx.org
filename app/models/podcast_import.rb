# encoding: utf-8

require 'prx_access'
require 'announce'
require 'addressable/uri'
require 'feedjira'
require 'itunes_category_validator'
require 'loofah'
require 'hash_serializer'

class PodcastImport < BaseModel
  include Announce::Publisher
  include PRXAccess
  include Rails.application.routes.url_helpers

  serialize :config, HashSerializer

  attr_accessor :feed, :templates, :stories, :podcast, :distribution

  belongs_to :user, -> { with_deleted }
  belongs_to :account, -> { with_deleted }
  belongs_to :series, -> { with_deleted }

  before_validation :set_defaults, on: :create

  validates :user_id, :account_id, :url, presence: true

  def set_config_url(config_url)
    c_url = Addressable::URI.parse(config_url)
    response = connection(c_url).get(c_url.path, c_url.query_values)
    self.config = ActiveSupport::JSON.decode(response.body).try(:with_indifferent_access)
  end

  def set_defaults
    self.status ||= 'created'
    self.config ||= {}
  end

  def import_later
    PodcastImportJob.perform_later self
  end

  def import
    update_attributes(status: 'started')

    # Request the RSS feed
    get_feed
    update_attributes(status: 'feed retrieved')

    # Create the series
    create_series_from_podcast
    update_attributes(status: 'series created')

    # Update podcast attributes
    create_podcast
    update_attributes(status: 'podcast created')

    # Create the episodes
    create_stories
    update_attributes(status: 'complete')
  rescue StandardError => err
    update_attributes(status: 'failed')
    raise err
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

  def create_series_from_podcast(feed = self.feed)
    # create the series
    self.series = create_series!(
      app_version: PRX::APP_VERSION,
      account: account,
      title: clean_string(feed.title),
      short_description: clean_string(short_desc(feed)),
      description_html: feed_description(feed)
    )
    save!

    # Add images to the series
    if !feed.itunes_image.blank?
      image = series.images.create!(
        upload: clean_string(feed.itunes_image),
        purpose: Image::PROFILE
      )
      announce_image(image)
    end

    if feed.image && feed.image.url
      image = series.images.create!(
        upload: clean_string(feed.image.url),
        purpose: Image::THUMBNAIL
      )
      announce_image(image)
    end

    self.distribution = Distributions::PodcastDistribution.create!(
      distributable: series
    )

    series
  end

  def create_podcast
    podcast_attributes = {}
    %w(copyright language update_frequency update_period).each do |atr|
      podcast_attributes[atr.to_sym] = clean_string(feed.send(atr))
    end

    if config[:program]
      podcast_attributes[:path] = config[:program]
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

    self.podcast = distribution.add_podcast_to_feeder(podcast_attributes)
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

  def person(arg)
    return nil if arg.blank?

    email = name = nil
    if arg.is_a?(Hash)
      email = clean_string(arg[:email])
      name = clean_string(arg[:name])
    else
      s = clean_string(arg)
      if match = s.match(/(.+) \((.+)\)/)
        email = match[1]
        name = match[2]
      else
        name = s
      end
    end

    { name: name, email: email }
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

  def create_stories
    self.templates ||= []
    feed.entries.map do |entry|
      story = create_story(entry, series)
      create_episode(story, entry)
      story
    end
  end

  def entry_description(entry)
    atr = entry_description_attribute(entry)
    clean_text(entry[atr])
  end

  def entry_description_attribute(entry)
    [:content, :itunes_summary, :description, :title].find { |d| !entry[d].blank? }
  end

  def create_story(entry, series)
    story = series.stories.create!(
      app_version: PRX::APP_VERSION,
      creator_id: user_id,
      account_id: series.account_id,
      title: clean_string(entry[:title]),
      short_description: clean_string(short_desc(entry)),
      description_html: entry_description(entry),
      tags: Array(entry[:categories]).map(&:strip).reject(&:blank?),
      published_at: entry[:published],
      season_identifier: entry[:itunes_season],
      episode_identifier: entry[:itunes_episode],
      clean_title: entry[:itunes_title]
    )

    audio_files = []
    if config[:audio] && config[:audio][entry.entry_id]
      audio_files = config[:audio][entry.entry_id]
    elsif enclosure = enclosure_url(entry)
      audio_files = [enclosure]
    end

    # add the audio version
    template = get_or_create_template(audio_files.size)
    version = story.audio_versions.create!(
      audio_version_template: template,
      label: 'Podcast Audio',
      explicit: explicit(entry[:itunes_explicit])
    )

    audio_files.each_with_index do |af, i|
      af = af.gsub(' ', '%20')
      audio = version.audio_files.create!(label: "Segment #{i + 1}", upload: af)
      announce_audio(audio)
    end

    # add the image if it is different from the channel itunes_image
    if entry.itunes_image && feed.itunes_image != entry.itunes_image
      image = story.images.create!(upload: entry.itunes_image)
      announce_image(image)
    end

    story
  end

  def get_or_create_template(segments)
    num_segments = [segments.to_i, 1].max
    if !templates[num_segments]
      template = series.audio_version_templates.create!(
        label: "Podcast Audio #{num_segments} #{'segment'.pluralize(num_segments)}",
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

      distribution.distribution_templates.create!(
        distribution: distribution,
        audio_version_template: template
      )
      self.templates[num_segments] = template
    end
    templates[num_segments]
  end

  def enclosure_url(entry)
    url = entry[:feedburner_orig_enclosure_link] || entry[:enclosure].try(:url)
    clean_string(url)
  end

  def create_episode(story, entry)
    # create the distro from the story
    distro = StoryDistributions::EpisodeDistribution.create(
      distribution: distribution,
      story: story,
      guid: entry.entry_id
    )

    create_attributes = {}
    if entry[:itunes_summary] && :itunes_summary != entry_description_attribute(entry)
      create_attributes[:summary] = clean_text(entry[:itunes_summary])
    end
    create_attributes[:author] = person(entry[:itunes_author] || entry[:author] || entry[:creator])
    create_attributes[:block] = (clean_string(entry[:itunes_block]) == 'yes')
    create_attributes[:explicit] = explicit(entry[:itunes_explicit])
    create_attributes[:guid] = clean_string(entry.entry_id)
    create_attributes[:is_closed_captioned] = closed_captioned?(entry)
    create_attributes[:is_perma_link] = entry[:is_perma_link]
    create_attributes[:keywords] = (entry[:itunes_keywords] || '').split(',').map(&:strip)
    create_attributes[:position] = entry[:itunes_order]
    create_attributes[:url] = episode_url(entry) || distro.default_url(story)
    create_attributes[:itunes_type] = entry[:itunes_episode_type] unless entry[:itunes_episode_type].blank?

    distro.add_episode_to_feeder(create_attributes)
  end

  def episode_url(entry)
    url = clean_string(entry[:feedburner_orig_link] || entry[:url] || entry[:link])
    if url =~ /libsyn\.com/
      url = nil
    end
    url
  end

  def closed_captioned?(entry)
    (clean_string(entry[:itunes_is_closed_captioned]) == 'yes')
  end

  def explicit(str)
    return nil if str.blank?
    explicit = clean_string(str).downcase
    if %w(true yes).include?(explicit)
      explicit = 'explicit'
    elsif %w(no false).include?(explicit)
      explicit = 'clean'
    end
    explicit
  end

  def short_desc(item)
    [item.itunes_subtitle, item.description, item.title].find do |field|
      !field.blank? && field.split.length < 50
    end
  end

  def clean_string(str)
    return nil if str.blank?
    return str if !str.is_a?(String)
    str.strip
  end

  def clean_text(text)
    return nil if text.blank?
    result = remove_feedburner_tracker(text)
    sanitize_html(result)
  end

  def remove_feedburner_tracker(str)
    return nil if str.blank?
    regex = /<img src="http:\/\/feeds\.feedburner\.com.+" height="1" width="1" alt=""\/>/
    str.sub(regex, '').strip
  end

  def sanitize_html(text)
    return nil if text.blank?
    sanitizer = Rails::Html::WhiteListSanitizer.new
    sanitizer.sanitize(Loofah.fragment(text).scrub!(:prune).to_s).strip
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

  def announce_image(image)
    announce('image', 'create', Api::Msg::ImageRepresenter.new(image).to_json)
  end

  def announce_audio(audio)
    announce('audio', 'create', Api::Msg::AudioFileRepresenter.new(audio).to_json)
  end
end
