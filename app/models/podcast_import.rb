# encoding: utf-8

require 'prx_access'
require 'announce'
require 'addressable/uri'
require 'feedjira'
require 'itunes_category_validator'
require 'loofah'

class PodcastImport < BaseModel
  include Announce::Publisher
  include PRXAccess
  include Rails.application.routes.url_helpers

  attr_accessor :feed, :template, :stories, :podcast, :distribution

  belongs_to :user, -> { with_deleted }
  belongs_to :account, -> { with_deleted }
  belongs_to :series, -> { with_deleted }

  before_validation :set_defaults, on: :create

  validates :user_id, :account_id, :url, presence: true

  def set_defaults
    self.status ||= 'created'
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
    result = [feed.itunes_summary, feed.description].find { |d| !d.blank? }.try(:strip)
    result = sanitize_html(result)
    result
  end

  def create_series_from_podcast(feed = self.feed)
    # create the series
    self.series = create_series!(
      app_version: PRX::APP_VERSION,
      account: account,
      title: feed.title,
      short_description: feed.itunes_subtitle,
      description_html: feed_description(feed)
    )
    save!

    # Add images to the series
    if !feed.itunes_image.blank?
      image = series.images.create!(
        upload: feed.itunes_image,
        purpose: Image::PROFILE
      )
      announce_image(image)
    end

    if feed.image && feed.image.url
      image = series.images.create!(
        upload: feed.image.url,
        purpose: Image::THUMBNAIL
      )
      announce_image(image)
    end

    # Add the template and a single file template
    self.template = series.audio_version_templates.create!(
      label: 'Podcast Audio',
      promos: false,
      length_minimum: 0,
      length_maximum: 0
    )

    template.audio_file_templates.create!(
      position: 1,
      label: 'Segment A',
      length_minimum: 0,
      length_maximum: 0
    )

    self.distribution = Distributions::PodcastDistribution.create!(
      distributable: series,
      audio_version_template: template
    )

    series
  end

  def create_podcast
    podcast_attributes = {}
    %w(copyright language update_frequency update_period).each do |atr|
      podcast_attributes[atr.to_sym] = feed.send(atr)
    end

    podcast_attributes[:summary] = feed.itunes_summary.try(:strip)
    podcast_attributes[:link] = feed.url
    podcast_attributes[:explicit] = feed.itunes_explicit
    podcast_attributes[:new_feed_url] = feed.itunes_new_feed_url
    podcast_attributes[:enclosure_prefix] ||= enclosure_prefix(feed.entries.first)
    podcast_attributes[:path] ||= feed.feedburner_name
    podcast_attributes[:feedburner_url] ||= feedburner_url(feed.feedburner_name)
    podcast_attributes[:url] ||= feedburner_url(feed.feedburner_name)

    podcast_attributes[:author] = person(feed.itunes_author)
    podcast_attributes[:managing_editor] = person(feed.managing_editor)
    podcast_attributes[:owner] = owner(feed.itunes_owners)

    podcast_attributes[:itunes_categories] = parse_itunes_categories(feed)
    podcast_attributes[:categories] = parse_categories(feed)
    podcast_attributes[:complete] = (feed.itunes_complete == 'yes')
    podcast_attributes[:copyright] ||= feed.media_copyright
    podcast_attributes[:keywords] = parse_keywords(feed)

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
    fb_name ? "http://feeds.feedburner.com/#{fb_name}" : nil
  end

  def owner(itunes_owners)
    if o = itunes_owners.try(:first)
      { name: o.name, email: o.email }
    end
  end

  def person(arg)
    return nil if arg.blank?

    email = name = nil
    if arg.is_a?(Hash)
      email = arg[:email]
      name = arg[:name]
    else
      s = arg.to_s.try(:strip)
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
    feed.entries.map do |entry|
      story = create_story(entry, series)
      create_episode(story, entry)
      story
    end
  end

  def entry_description(entry)
    atr = [:content, :itunes_summary, :description].find { |d| !entry[d].blank? }
    result = entry[atr].try(:strip) if atr
    result = remove_feedburner_tracker(result)
    result = sanitize_html(result)
    result
  end

  def remove_feedburner_tracker(str)
    return nil if str.blank?
    str.sub(/<img src="http:\/\/feeds\.feedburner\.com.+" height="1" width="1" alt=""\/>/, '')
  end

  def create_story(entry, series)
    story = series.stories.create!(
      app_version: PRX::APP_VERSION,
      creator_id: user_id,
      account_id: series.account_id,
      title: entry[:title],
      short_description: entry[:itunes_subtitle],
      description_html: entry_description(entry),
      tags: entry[:categories],
      published_at: entry[:published]
    )

    # add the audio version
    version = story.audio_versions.create!(
      audio_version_template: template,
      label: 'Podcast Audio',
      explicit: entry[:itunes_explicit]
    )

    # add the audio
    if enclosure = enclosure_url(entry)
      audio = version.audio_files.create!(label: 'Segment A', upload: enclosure)
      announce_audio(audio)
    end

    # add the image
    if entry.itunes_image
      image = story.images.create!(upload: entry.itunes_image)
      announce_image(image)
    end

    story
  end

  def enclosure_url(entry)
    entry[:feedburner_orig_enclosure_link] || entry[:enclosure].try(:url)
  end

  def create_episode(story, entry)
    # create the distro from the story
    distro = StoryDistributions::EpisodeDistribution.create(
      distribution: distribution,
      story: story,
      guid: entry.entry_id
    )

    create_attributes = {}
    if entry[:itunes_summary] && entry[:itunes_summary] != entry_description(entry)
      create_attributes[:summary] = entry[:itunes_summary].try(:strip)
    end
    create_attributes[:author] = person(entry[:itunes_author] || entry[:author] || entry[:creator])
    create_attributes[:block] = (entry[:itunes_block] == 'yes')
    create_attributes[:explicit] = entry[:itunes_explicit]
    create_attributes[:guid] = entry.entry_id
    create_attributes[:is_closed_captioned] = (entry[:itunes_is_closed_captioned] == 'yes')
    create_attributes[:is_perma_link] = entry[:is_perma_link]
    create_attributes[:keywords] = (entry[:itunes_keywords] || '').split(',').map(&:strip)
    create_attributes[:position] = entry[:itunes_order]
    create_attributes[:url] = episode_url(entry)

    distro.add_episode_to_feeder(create_attributes)
  end

  def episode_url(entry)
    url = entry[:feedburner_orig_link] || entry[:url] || entry[:link]
    if url =~ /libsyn\.com/
      url = nil
    end
    url
  end

  def sanitize_html(text)
    return nil if text.blank?
    sanitizer = Rails::Html::WhiteListSanitizer.new
    sanitizer.sanitize(Loofah.fragment(text).scrub!(:prune).to_s)
  end

  def uri
    @uri ||= Addressable::URI.parse(url)
  end

  def connection
    conn_uri = "#{uri.scheme}://#{uri.host}:#{uri.port}"
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
