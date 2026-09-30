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

    before_validation :build_apple_delivery_token
    validate :apple_delivery_requires_token
    validate :apple_public_dependents_block_private
    before_destroy :protect_apple_delivery_connection, prepend: true
  end

  # Megaphone feeds deliver to Apple without an Apple show connection.
  def apple_connectable?
    !is_a?(Feeds::MegaphoneFeed)
  end

  # Other feeds' delivery depends on this feed's show staying public. A
  # feed's own delivery through its own show can go private.
  private def apple_public_dependents_block_private
    return unless private? && private_changed? && apple_show_feed_binding

    config = apple_show_feed_binding.delegated_delivery_config
    if config && config.feed_id != id
      label = config.feed&.label || "another feed"
      errors.add(:private, "cannot be enabled while #{label} delivers to this feed's Apple show")
    end
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
