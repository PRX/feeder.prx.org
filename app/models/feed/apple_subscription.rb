class Feed::AppleSubscription < Feed
  DEFAULT_FEED_SLUG = "apple-delegated-delivery-subscriptions"
  DEFAULT_TITLE = "Apple Delegated Delivery Subscriptions"
  DEFAULT_AUDIO_FORMAT = {"f" => "flac", "b" => 16, "c" => 2, "s" => 44100}.freeze

  after_initialize :set_defaults

  has_one :apple_config, class_name: "::Apple::Config", dependent: :destroy, autosave: true, validate: true
  has_one :key,
    through: :apple_config,
    class_name: "Apple::Key",
    dependent: :destroy,
    foreign_key: :key_id

  accepts_nested_attributes_for :apple_config, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :key, allow_destroy: true, reject_if: :all_blank

  validate :unchanged_defaults
  validate :only_apple_feed
  validate :must_be_private

  def set_defaults
    self.slug ||= DEFAULT_FEED_SLUG
    self.title ||= DEFAULT_TITLE
    self.audio_format ||= DEFAULT_AUDIO_FORMAT
  end

  def self.model_name
    Feed.model_name
  end

  def self.find_or_build_private_feed(podcast)
    if (existing = podcast.feeds.find_by(slug: DEFAULT_FEED_SLUG, title: DEFAULT_TITLE))
      # TODO, handle partitions on apple models via the apple_config
      # Until then it's not safe to have multiple apple_configs for the same podcast
      Rails.logger.error("Found existing private feed for #{podcast.title}!")
      Rails.logger.error("Do you want to continue? (y/N)")
      raise "Stopping find_or_build_private_feed" if $stdin.gets.chomp.downcase != "y"

      return existing
    end
    default_feed = podcast.default_feed

    Feed.new(
      display_episodes_count: default_feed.display_episodes_count,
      slug: DEFAULT_FEED_SLUG,
      title: DEFAULT_TITLE,
      audio_format: DEFAULT_AUDIO_FORMAT,
      include_zones: ["billboard", "sonic_id"],
      tokens: [FeedToken.new(label: DEFAULT_TITLE)],
      podcast: podcast
    )
  end

  # TODO: this a helper for onboarding via console, retrofit when the UX catches up
  def self.build_apple_config(podcast, key)
    if podcast.apple_config
      Rails.logger.error("Found existing apple config for #{podcast.title}!")
      Rails.logger.error("Do you want to continue? (y/N)")
      raise "Stopping build_apple_config" if $stdin.gets.chomp.downcase != "y"
    end

    Apple::Config.new(feed: find_or_build_private_feed(podcast), key: key)
  end

  def unchanged_defaults
    return unless self.persisted?

    if title_changed? || slug_changed?
      errors.add(:feed, "cannot change properties once set")
    end
  end

  def only_apple_feed
    existing_feed = Feed.where(podcast_id: self.podcast_id, type: "Feed::AppleSubscription")
    if existing_feed.present?
      errors.add(:podcast, "cannot have more than one apple subscription")
    end
  end

  def must_be_private
    if self.private != true
      errors.add(:feed, "must be a private feed")
    end
  end

  def publish_to_apple?
    !!apple_config&.publish_to_apple?
  end
end
