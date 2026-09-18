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

    accepts_nested_attributes_for :delegated_delivery_config,
      allow_destroy: true,
      reject_if: ->(attributes) { attributes["id"].blank? && attributes["show_feed_binding_id"].blank? }

    validate :apple_connection_requires_public_feed
    before_destroy :protect_apple_delivery_connection, prepend: true
  end

  def apple_connection
    if defined?(@apple_connection)
      @apple_connection
    else
      apple_show_feed_binding&.apple_show_id
    end
  end

  attr_writer :apple_connection

  def apple_connection_was
    apple_show_feed_binding&.apple_show_id
  end

  def apple_connection_changed?
    apple_connection.to_s != apple_connection_was.to_s
  end

  def save_with_apple_connection
    saved = false
    transaction do
      if save && save_apple_connection
        saved = true
      else
        raise ActiveRecord::Rollback
      end
    end
    saved
  end

  private def save_apple_connection
    return true unless public? && apple_connection_changed?

    binding = if apple_connection.blank?
      apple_show_feed_binding.tap(&:destroy)
    else
      Apple::ShowFeedBinding.connect_existing(feed: self, apple_show_id: apple_connection)
    end

    binding.errors.full_messages.each { |message| errors.add(:apple_connection, message) }
    association(:apple_show_feed_binding).reset if binding.errors.empty?
    binding.errors.empty?
  end

  def publish_to_apple?
    valid? && persisted? && !!delegated_delivery_config&.publish_to_apple?
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

  # Episodes Apple may upload before they are published.
  def integration_draft_episodes(integration)
    return episodes.none unless integration == :apple && delegated_delivery_config

    episodes.where("episodes.published_at IS NULL OR episodes.published_at > ?", Time.now - episode_offset_seconds.to_i)
  end

  private def apple_connection_requires_public_feed
    if private? && apple_show_feed_binding
      errors.add(:private, "cannot be enabled while connected to an Apple show")
    end
  end

  private def protect_apple_delivery_connection
    return if destroyed_by_association
    return unless apple_show_feed_binding&.delegated_delivery_config

    errors.add(:base, "Cannot delete a feed while delegated delivery uses its Apple connection")
    throw :abort
  end
end
