require "addressable/uri"
require "feedjira"
require "itunes_category_validator"
require "loofah"
require "hash_serializer"

class EpisodeImport < ActiveRecord::Base
  include ImportUtils

  serialize :entry, HashSerializer
  serialize :audio, HashSerializer

  belongs_to :episode, -> { with_deleted }, touch: true, optional: true
  belongs_to :podcast_import
  has_one :podcast, through: :podcast_import
  delegate :config, to: :podcast_import

  scope :having_duplicate_guids, -> do
    unscope(where: :has_duplicate_guid).where(has_duplicate_guid: true)
  end
  scope :complete, -> { where(status: COMPLETE) }

  before_validation :set_defaults, on: :create

  validates :entry, :guid, presence: true

  COMPLETE = "complete".freeze
  FAILED = "failed".freeze

  CREATED = "created".freeze
  AUDIO_SAVED = "audio saved".freeze
  RETRYING = "retrying".freeze
  EPISODE_SAVED = "episode saved".freeze

  def unlock_podcast
    if podcast_import.finished?
      podcast_import.podcast.update(locked: false)
    end
  end

  def retry!
    update(status: RETRYING)
    import_later
  end

  def set_defaults
    self.status ||= CREATED
    self.audio ||= {files: []}
  end

  def import_later
    EpisodeImportJob.perform_later self
    self
  end

  def import
    set_audio_metadata!
    update!(status: AUDIO_SAVED)

    create_or_update_episode!

    set_file_resources!

    update!(status: EPISODE_SAVED)

    episode.save!

    update!(status: COMPLETE)

    unlock_podcast

    episode
  rescue => err
    Rails.logger.error ([err.message]+err.backtrace).join($/)
    update(status: FAILED)
    raise err
  end

  def audio_content_params
    audio&.fetch("files")&.each_with_index&.map do |url, index|
      {position: index, original_url: url}
    end
  end

  def image_contents_params
    if (image = entry[:itunes_image])
      {original_url: image}
    end
  end

  def set_audio_metadata!
    audio_files = entry_audio_files(entry)
    update!(audio: audio_files)
  end

  def set_file_resources!
    episode.contents = audio_content_params
    episode.image = image_contents_params
    episode.save!
    episode.images.reset
    episode.contents.reset
    episode.copy_media
  end

  def entry_audio_files(entry)
    if config[:audio] && config[:audio][entry[:entry_id]]
      {files: (config[:audio][entry[:entry_id]] || [])}
    elsif (enclosure = enclosure_url(entry))
      {files: [enclosure]}
    end
  end

  def create_or_update_episode!
    self.episode ||= Episode.new(podcast: podcast)

    update_episode_with_entry!

    episode.save!
  end

  def update_episode_with_entry!
    episode.clean_title = entry[:itunes_title]
    episode.description = entry_description(entry)
    episode.episode_number = entry[:itunes_episode]
    episode.published_at = entry[:published]
    episode.season_number = entry[:itunes_season]
    episode.subtitle = clean_string(episode_short_desc(entry))
    episode.categories = Array(entry[:categories]).map(&:strip).reject(&:blank?)
    episode.title = clean_title(entry[:title])

    if entry[:itunes_summary] && entry_description_attribute(entry) != :itunes_summary
      episode.summary = clean_text(entry[:itunes_summary])
    end
    episode.author = person(entry[:itunes_author] || entry[:author] || entry[:creator])
    episode.block = (clean_string(entry[:itunes_block]) == "yes")
    episode.explicit = explicit(entry[:itunes_explicit])
    episode.original_guid = clean_string(entry[:entry_id])
    episode.is_closed_captioned = closed_captioned?(entry)
    episode.is_perma_link = entry[:is_perma_link]
    episode.keywords = (entry[:itunes_keywords] || "").split(",").map(&:strip)
    episode.position = entry[:itunes_order]
    # TODO: beta.prx.org urls
    episode.url = episode_url(entry) || default_episode_url(episode)
    episode.itunes_type = entry[:itunes_episode_type] unless entry[:itunes_episode_type].blank?

    episode
  end

  def entry_description(entry)
    atr = entry_description_attribute(entry)
    clean_text(entry[atr])
  end

  def entry_description_attribute(entry)
    [:content, :itunes_summary, :description, :title].find { |d| !entry[d].blank? }
  end

  def get_or_create_template(segments, enclosure)
    podcast_import.get_or_create_template(segments, enclosure)
  end

  def episode_url(entry)
    url = clean_string(entry[:feedburner_orig_link] || entry[:url] || entry[:link])
    if /libsyn\.com/.match?(url)
      url = nil
    end
    url
  end

  def closed_captioned?(entry)
    (clean_string(entry[:itunes_is_closed_captioned]) == "yes")
  end

  def episode_short_desc(item)
    [item[:itunes_subtitle], item[:description], item[:title]].find do |field|
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

  def account
    podcast_import.try(:account)
  end
end
