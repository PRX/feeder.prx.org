class Feeds::AppleSubscription < Feed
  DEFAULT_FEED_SLUG = "apple-delegated-delivery-subscriptions"
  DEFAULT_TITLE = "Apple Delegated Delivery Subscriptions"
  DEFAULT_AUDIO_FORMAT = {f: "mp3", b: 128, c: 2, s: 44100}.with_indifferent_access
  DEFAULT_ZONES = ["billboard", "sonic_id"]

  # min apple settings (though forcing a higher bitrate for mono)
  # https://podcasters.apple.com/support/893-audio-requirements
  MIN_MP3_BITRATE = 64
  MP3_CHANNELS = [1, 2]
  MIN_MP3_SAMPLERATE = 44100

  after_initialize :set_defaults

  after_create :republish_public_feed

  after_save_commit :update_apple_show

  has_one :apple_config, class_name: "::Apple::Config", dependent: :destroy, autosave: true, validate: true, inverse_of: :feed

  accepts_nested_attributes_for :apple_config, allow_destroy: true, reject_if: :all_blank

  validate :unchanged_defaults
  validate :only_apple_feed
  validate :must_be_private
  validate :must_have_token

  alias_method :config, :apple_config

  # for soft delete, need a unique slug to be able to make another
  def paranoia_destroy_attributes
    {
      deleted_at: current_time_from_proper_timezone,
      slug: "#{slug}-#{Time.now.to_i}"
    }
  end

  def mark_as_not_delivered!(episode)
    episode.apple_episode_delivery_status.mark_as_not_delivered!
  end

  def set_defaults
    self.slug ||= DEFAULT_FEED_SLUG
    self.title ||= DEFAULT_TITLE
    self.audio_format ||= guess_audio_format
    self.display_episodes_count ||= podcast&.default_feed&.display_episodes_count if new_record?
    self.include_zones ||= DEFAULT_ZONES
    self.tokens = [FeedToken.new(label: DEFAULT_TITLE)] if tokens.empty?
    self.private = true

    super
  end

  def update_apple_show
    if previous_changes[:apple_show_id]
      Apple::Show.connect_existing(apple_show_id, apple_config)
    end
  end

  def apple_show_options
    used_ids = Feed.apple.distinct.where("id != ?", id).pluck(:apple_show_id).compact
    api = Apple::Api.from_apple_config(apple_config)
    shows_json = Apple::Show.apple_shows_json(api) || []
    shows_json
      .filter { |sj| sj["attributes"]["publishingState"] != "ARCHIVED" }
      .filter { |sj| !used_ids.include?(sj["id"]) }
      .map { |sj| ["#{sj["id"]} (#{sj["attributes"]["title"]})", sj["id"]] }
  rescue => err
    logger.error(err)
    []
  end

  def guess_audio_format
    default_feed_audio_format || episode_audio_format || DEFAULT_AUDIO_FORMAT
  end

  def self.model_name
    Feed.model_name
  end

  def republish_public_feed
    PublishPublicFeedJob.perform_later(podcast)
  end

  def unchanged_defaults
    return unless persisted?

    if title_changed?
      errors.add(:title, "cannot change once set")
    end
    if slug_changed?
      errors.add(:slug, "cannot change once set")
    end
    if file_name_changed?
      errors.add(:file_name, "cannot change once set")
    end
  end

  def only_apple_feed
    existing_feed = Feeds::AppleSubscription.where(podcast_id: podcast_id).where.not(id: id)
    if existing_feed.any?
      errors.add(:podcast, "cannot have more than one apple subscription")
    end
  end

  def must_be_private
    if private != true
      errors.add(:private, "must be a private feed")
    end
  end

  def must_have_token
    if tokens.blank?
      errors.add(:tokens, "must have a token")
    end
  end

  def integration_type
    :apple
  end

  def publish_integration!
    if publish_integration?
      apple_config.build_publisher.publish!
    end
  end

  def publish_integration?
    publish_to_apple?
  end

  def publish_to_apple?
    !!apple_config&.publish_to_apple?
  end

  def default_feed_audio_format
    af = podcast&.default_feed&.audio_format
    standardize_audio_format(af) if af && af[:f] == "mp3"
  end

  def episode_audio_format
    episodes = podcast&.episodes&.published&.includes(:contents)&.limit(10) || []
    contents = episodes.map { |e| e.contents.first }.compact
    mp3_contents = contents.select { |c| c.audio? && c.mime_type == "audio/mpeg" }

    if mp3_contents.any?
      max_bitrate = mp3_contents.map { |c| c.bit_rate.to_i }.max
      max_channels = mp3_contents.map { |c| c.channels.to_i }.max
      max_sample = mp3_contents.map { |c| c.sample_rate.to_i }.max
      standardize_audio_format({b: max_bitrate, c: max_channels, s: max_sample})
    end
  end

  def standardize_audio_format(af)
    {
      f: "mp3",
      b: [MIN_MP3_BITRATE, af[:b]].compact.max,
      c: MP3_CHANNELS.include?(af[:c]) ? af[:c] : MP3_CHANNELS.min,
      s: [MIN_MP3_SAMPLERATE, af[:s]].compact.max
    }.with_indifferent_access
  end
end
