require "active_support/concern"

module FeedApple
  extend ActiveSupport::Concern

  included do
    has_one :apple_sync_log, -> { feeds.apple }, foreign_key: :feeder_id, class_name: "Apple::SyncLog"
    has_one :apple_show_feed_binding, class_name: "Apple::ShowFeedBinding", dependent: :destroy
    has_one :delegated_delivery_config,
      class_name: "Apple::DelegatedDeliveryConfig",
      dependent: :destroy,
      autosave: true,
      validate: true,
      inverse_of: :feed

    before_validation :apply_apple_settings
    before_validation :build_apple_delivery_token
    validate :apple_settings_must_be_valid
    validate :apple_delivery_requires_token
    validate :apple_public_dependents_block_private
    validate :apple_unused_connection_blocks_private
    before_save :connect_apple_show
    after_save :disconnect_apple_show
    before_destroy :protect_apple_delivery_connection, prepend: true

    # Feeds connected to an Apple show or delivering to one.
    scope :apple_connected, -> { where(id: Apple::ShowFeedBinding.select(:feed_id)).or(where(id: Apple::DelegatedDeliveryConfig.select(:feed_id))) }
  end

  # The feed form's Apple settings, saved with the feed.
  def apple_settings
    @apple_settings ||= Apple::FeedSettings.new(self)
  end

  def apple_settings=(attributes)
    @apple_settings = Apple::FeedSettings.new(self, attributes || {})
  end

  # Reloading drops unsaved settings, since they cache the feed's records.
  def reload(*)
    @apple_settings = nil
    super
  end

  # Settings are only applied once assigned, so other saves skip them.
  private def apply_apple_settings
    @apple_settings&.apply
  end

  private def apple_settings_must_be_valid
    errors.add(:apple_settings, :invalid) if @apple_settings&.invalid?
  end

  private def connect_apple_show
    return if @apple_settings.nil? || @apple_settings.connect

    errors.add(:apple_settings, :invalid)
    throw :abort
  end

  # A later save of this feed starts from the saved settings.
  private def disconnect_apple_show
    return unless @apple_settings

    unless @apple_settings.disconnect && @apple_settings.save_hls_config
      errors.add(:apple_settings, :invalid)
      raise ActiveRecord::RecordInvalid, self
    end
    @apple_settings = nil
  end

  # Megaphone handles its own distribution, so its feeds never connect to an Apple show here.
  def apple_connectable?
    !is_a?(Feeds::MegaphoneFeed)
  end

  # Other feeds' delivery and HLS video depend on this feed's show staying
  # public. A feed's own delivery through its own show can go private.
  private def apple_public_dependents_block_private
    return unless private? && private_changed? && apple_show_feed_binding

    config = apple_show_feed_binding.delegated_delivery_config
    if config && config.feed_id != id
      label = config.feed&.label || "another feed"
      errors.add(:private, "cannot be enabled while #{label} delivers to this feed's Apple show")
    end

    if apple_show_feed_binding.hls_config&.enabled?
      errors.add(:private, "cannot be enabled while HLS video is enabled")
    end
  end

  # A connection nothing delivers through would change from a public show
  # to this feed's own show, so it must be disconnected or delivered
  # through first.
  private def apple_unused_connection_blocks_private
    return unless private? && private_changed? && apple_show_feed_binding

    # Reported by apple_public_dependents_block_private.
    dependent = apple_show_feed_binding.delegated_delivery_config
    return if dependent && dependent.feed_id != id
    return if delivering_through_own_apple_show?

    errors.add(:private, "cannot be enabled while this feed is connected to an Apple show. Disconnect it or publish this feed to its own Apple show first")
  end

  # Read from the feed's config, which holds this save's delivery changes.
  # Compare bindings, since a binding connected in this save isn't on the
  # config's foreign key until the config saves.
  private def delivering_through_own_apple_show?
    config = delegated_delivery_config
    config.present? && !config.marked_for_destruction? && config.show_feed_binding&.id == apple_show_feed_binding.id
  end

  def publish_to_apple?
    persisted? && !!delegated_delivery_config&.publish_to_apple?
  end

  # Configured integrations, including those whose publishing is paused.
  def integration_types
    delegated_delivery_config.present? ? [:apple] : []
  end

  def integration_config(integration)
    delegated_delivery_config if integration == :apple
  end

  def publish_integration?(integration)
    integration == :apple && publish_to_apple?
  end

  def publish_integration!(integration)
    delegated_delivery_config.build_publisher.publish! if publish_integration?(integration)
  end

  # Whether an episode is eligible for this feed's Apple delivery.
  # Apple can upload drafts beyond the rendered RSS window.
  def integration_episode?(episode, integration)
    return false unless integration == :apple && delegated_delivery_config

    if episode.published_by?(episode_offset_seconds.to_i)
      feed_episode?(episode)
    elsif episode.enclosure_ready?(true)
      integration_draft_episodes(integration).where(id: episode.id).exists?
    else
      false
    end
  end

  # The Apple facade for an episode. Apple state is scoped to a
  # show, so the facade is built from this feed's connection.
  def integration_episode(episode, integration)
    return unless integration == :apple && delegated_delivery_config

    show = delegated_delivery_config.build_show
    show.build_integration_episode(episode) if show.apple_id.present?
  end

  # Only select pre-release uploads when the feed can serve their audio.
  def integration_draft_episodes(integration)
    return episodes.none unless integration == :apple && delegated_delivery_config && serve_drafts

    episodes.where("episodes.published_at IS NULL OR episodes.published_at > ?", Time.now - episode_offset_seconds.to_i)
  end

  private def build_apple_delivery_token
    return unless private? && delegated_delivery_config&.new_record? && !delegated_delivery_config.marked_for_destruction?

    tokens.build(label: Apple::DelegatedDeliveryConfig::DEFAULT_TOKEN_LABEL) if active_apple_tokens.empty?
  end

  private def apple_delivery_requires_token
    delivering = delegated_delivery_config && !delegated_delivery_config.marked_for_destruction?
    return if public? || !(delivering || apple_show_feed_binding)

    errors.add(:tokens, "must have a token") if active_apple_tokens.empty?
  end

  def active_apple_tokens
    tokens.reject { |token| token.marked_for_destruction? || token.destroyed? }
  end

  # A feed's own delivery through its own show goes with it.
  private def protect_apple_delivery_connection
    return if destroyed_by_association

    config = apple_show_feed_binding&.delegated_delivery_config
    return if config.nil? || config.feed_id == id

    errors.add(:base, "Cannot delete a feed while delegated delivery uses its Apple connection")
    throw :abort
  end
end
