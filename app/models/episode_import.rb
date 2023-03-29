require "addressable/uri"
require "feedjira"
require "itunes_category_validator"
require "loofah"
require "hash_serializer"

class EpisodeImport < ActiveRecord::Base
  include ImportUtils

  serialize :entry, HashSerializer
  serialize :audio, HashSerializer

  belongs_to :story, -> { with_deleted }, class_name: "Story", foreign_key: "piece_id", touch: true
  belongs_to :podcast_import
  has_one :series, through: :podcast_import
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
  STORY_SAVED = "story saved".freeze
  EPISODE_SAVED = "episode saved".freeze

  def unlock_podcast
    if podcast_import.finished?
      podcast_import.podcast_distribution.update_podcast!(locked: false)
    end
  end

  def retry!
    update_attributes(status: RETRYING)
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
    update_episode_audio!
    update_attributes!(status: AUDIO_SAVED)
    create_or_update_story!
    update_attributes!(status: STORY_SAVED, piece_id: story.id)
    create_or_update_episode!
    update_attributes!(status: EPISODE_SAVED)
    story.save!
    update_search_index!
    update_attributes!(status: COMPLETE)

    announce(:story, :update, Api::Msg::StoryRepresenter.new(story).to_json)
    unlock_podcast

    story
  rescue => err
    update_attributes(status: FAILED)
    raise err
  end

  def update_search_index!
    SearchIndexerJob.set(wait: 5.minutes).perform_later(story)
  end

  def update_episode_audio!
    audio_files = entry_audio_files(entry)
    update_attributes!(audio: audio_files)
  end

  def entry_audio_files(entry)
    if config[:audio] && config[:audio][entry[:entry_id]]
      {files: (config[:audio][entry[:entry_id]] || [])}
    elsif enclosure = enclosure_url(entry)
      {files: [enclosure]}
    end
  end

  def create_or_update_story!
    story ? update_story_with_entry! : create_story_with_entry!
  end

  def create_story_with_entry!
    self.story = Story.create!(series: series, skip_searchable: true)
    update_story_with_entry!
  end

  def update_story_with_entry!(story = self.story)
    story.app_version = PRX::APP_VERSION
    story.creator_id = podcast_import.user_id
    story.account_id = series.account_id
    story.title = clean_title(entry[:title])
    story.short_description = clean_string(episode_short_desc(entry))
    story.description_html = entry_description(entry)
    story.tags = Array(entry[:categories]).map(&:strip).reject(&:blank?)
    story.published_at = entry[:published]
    story.season_identifier = entry[:itunes_season]
    story.episode_identifier = entry[:itunes_episode]
    story.clean_title = entry[:itunes_title]

    new_audio = update_audio
    new_images = update_image

    story.skip_searchable = true
    story.save!

    new_audio.each { |a| announce_audio(a) }
    new_images.each { |i| announce_image(i) }
    story
  end

  def update_image
    if !entry[:itunes_image]
      story.images.destroy_all
      return []
    end

    to_destroy = []
    to_insert = []

    if story.images.size > 1
      to_destroy = story.images[1..]
    end

    existing_image = story.images.first

    if existing_image && !files_match?(existing_image, entry[:itunes_image])
      to_destroy << existing_image
      existing_image = nil
    end

    if !existing_image
      new_image = story.images.build(upload: entry[:itunes_image])
      to_insert << new_image
    end

    story.images.destroy(to_destroy) if to_destroy.size > 0

    to_insert
  end

  def update_audio
    if audio.blank? || audio[:files].blank?
      story.audio_versions.destroy_all
      return []
    end

    if story.audio_versions.blank?
      template = get_or_create_template(audio, entry["enclosure"]["type"])
      version = story.audio_versions.build(
        audio_version_template: template,
        label: "Podcast Audio",
        explicit: explicit(entry[:itunes_explicit])
      )
    else
      version = story.audio_versions.first
    end

    audio_files = version.audio_files || []
    to_insert = []
    to_destroy = []

    if audio_files.size > audio[:files].size
      to_destroy = audio_files[audio[:files].size..(audio[:files].size - 1)]
    end

    audio[:files].each_with_index do |audio_url, i|
      existing_audio = audio_files[i]

      if existing_audio && !files_match?(existing_audio, audio_url)
        to_destroy << existing_audio
        existing_audio = nil
      end

      if !existing_audio
        new_audio = version.audio_files.build(
          upload: audio_url.gsub(" ", "%20"),
          label: "Segment #{i + 1}",
          position: (i + 1)
        )
        to_insert << new_audio
      end
    end

    version.audio_files.destroy(to_destroy) if to_destroy.size > 0

    to_insert.each { |af| version.audio_files << af }

    to_insert
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

  def create_or_update_episode!
    episode_attributes = {}
    if entry[:itunes_summary] && entry_description_attribute(entry) != :itunes_summary
      episode_attributes[:summary] = clean_text(entry[:itunes_summary])
    end
    episode_attributes[:author] = person(entry[:itunes_author] || entry[:author] || entry[:creator])
    episode_attributes[:block] = (clean_string(entry[:itunes_block]) == "yes")
    episode_attributes[:explicit] = explicit(entry[:itunes_explicit])
    episode_attributes[:guid] = clean_string(entry[:entry_id])
    episode_attributes[:is_closed_captioned] = closed_captioned?(entry)
    episode_attributes[:is_perma_link] = entry[:is_perma_link]
    episode_attributes[:keywords] = (entry[:itunes_keywords] || "").split(",").map(&:strip)
    episode_attributes[:position] = entry[:itunes_order]
    episode_attributes[:url] = episode_url(entry) || default_story_url(story)
    episode_attributes[:itunes_type] = entry[:itunes_episode_type] unless entry[:itunes_episode_type].blank?

    # if there is a distro, and an episode, then announce will sync changes
    if !distro = story.distributions.where(type: "StoryDistributions::EpisodeDistribution").first
      # create the distro from the story
      distro = StoryDistributions::EpisodeDistribution.create!(
        distribution: series.distributions.first,
        story: story,
        guid: entry[:entry_id]
      )
    end

    distro.create_or_update_episode(episode_attributes)
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

  def self.policy_class
    AccountablePolicy
  end
end
