class Feeds::AppleSubscription < Feed
  DEFAULT_FEED_SLUG = "apple-delegated-delivery-subscriptions"
  DEFAULT_TITLE = "Apple Delegated Delivery Subscriptions"
  DEFAULT_AUDIO_FORMAT = {"f" => "flac", "b" => 16, "c" => 2, "s" => 44100}.freeze
  DEFAULT_ZONES = ["billboard", "sonic_id"]

  after_initialize :set_defaults

  after_create :republish_public_feed

  has_one :apple_config, class_name: "::Apple::Config", dependent: :destroy, autosave: true, validate: true, inverse_of: :feed

  accepts_nested_attributes_for :apple_config, allow_destroy: true, reject_if: :all_blank

  validate :unchanged_defaults
  validate :only_apple_feed
  validate :must_be_private
  validate :must_have_token

  def set_defaults
    self.slug ||= DEFAULT_FEED_SLUG
    self.title ||= DEFAULT_TITLE
    self.audio_format ||= DEFAULT_AUDIO_FORMAT
    self.display_episodes_count ||= podcast&.default_feed&.display_episodes_count
    self.include_zones ||= DEFAULT_ZONES
    self.tokens = [FeedToken.new(label: DEFAULT_TITLE)] if tokens.empty?
    self.private = true

    super
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
    if audio_format_changed?
      errors.add(:audio_format, "cannot change once set")
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

  def apple?
    true
  end

  def publish_to_apple?
    !!apple_config&.publish_to_apple?
  end
end
