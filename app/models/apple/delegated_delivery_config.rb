# frozen_string_literal: true

module Apple
  class DelegatedDeliveryConfig < ApplicationRecord
    self.table_name = "apple_configs"

    ROUTING_SOURCES = {
      "legacy" => :legacy,
      "show_feed_binding" => :show_feed_binding
    }.freeze

    belongs_to :feed
    belongs_to :key, class_name: "Apple::Key", optional: true, validate: true, autosave: true
    belongs_to :show_feed_binding, class_name: "Apple::ShowFeedBinding", optional: true, inverse_of: :delegated_delivery_configs

    validate :podcast_has_one_apple_config
    validate :not_default_feed

    # backwards-compatible credential getters
    delegate :provider_id, to: :routing_key
    delegate :key_id, to: :routing_key
    delegate :key_pem, to: :routing_key
    delegate :key_pem_b64, to: :routing_key

    # backwards-compatible associations
    delegate :podcast, to: :feed, allow_nil: true
    delegate :id, :title, to: :podcast, prefix: true, allow_nil: true
    alias_method :private_feed, :feed

    accepts_nested_attributes_for :key

    def self.routing_source
      source = ENV.fetch("APPLE_ROUTING_SOURCE", "legacy")
      ROUTING_SOURCES.fetch(source) do
        raise ArgumentError,
          "Unsupported APPLE_ROUTING_SOURCE=#{source.inspect}; expected one of #{ROUTING_SOURCES.keys.join(", ")}"
      end
    end

    def self.find_or_build_apple_feed(podcast)
      existing_feed = Feeds::AppleSubscription.find_by_podcast_id(podcast.id)
      existing_feed.present? ? existing_feed : Feeds::AppleSubscription.new(podcast_id: podcast.id)
    end

    # TODO: this a helper for onboarding via console, retrofit when the UX catches up
    def self.build_apple_config(podcast, key)
      if podcast.apple_config
        Rails.logger.error("Found existing apple config for #{podcast.title}!")
        Rails.logger.error("Do you want to continue? (y/N)")
        raise "Stopping build_apple_config" if $stdin.gets.chomp.downcase != "y"
      end

      new(feed: find_or_build_apple_feed(podcast), key: key)
    end

    def self.mark_as_delivered!(apple_publisher)
      apple_publisher.episodes_to_sync.each do |episode|
        if episode.podcast_container&.needs_delivery? == false
          episode.feeder_episode.apple_mark_as_delivered!
        end
      end
    end

    def self.setup_delegated_delivery(podcast, key: nil, apple_config: nil, apple_show_id: nil)
      ac = apple_config || build_apple_config(podcast, key)
      ac.save!

      return "No apple show id -- skip connect existing " unless apple_show_id.present?

      Apple::Show.connect_existing(apple_show_id, ac)

      pub = ac.build_publisher
      # Poll all the episodes, to get a top-level view of what has remote state.
      # Just the episode endpoint, for speed and to avoid rate-limiting.
      pub.poll_all_episodes!

      # Now poll the episodes in the feed in their entirety,  to get a view of what has been added.
      pub.poll!

      mark_as_delivered!(pub)
    end

    def routing_source
      self.class.routing_source
    end

    def routing_key
      case routing_source
      when :legacy
        key
      when :show_feed_binding
        show_feed_binding&.apple_key
      end
    end

    def public_feed
      case routing_source
      when :legacy
        legacy_public_feed
      when :show_feed_binding
        show_feed_binding&.feed
      end
    end

    def apple_show_id
      case routing_source
      when :legacy
        legacy_apple_show_id
      when :show_feed_binding
        show_feed_binding&.apple_show_id
      end
    end

    def legacy_public_feed
      podcast&.public_feed
    end

    def legacy_apple_show_id
      legacy_public_feed&.apple_sync_log&.external_id.presence || private_feed&.apple_show_id.presence
    end

    def delivery_feed
      feed
    end

    def not_default_feed
      if feed&.default?
        errors.add(:feed, "cannot use default feed")
      end
    end

    def podcast_has_one_apple_config
      all_feeds = Feed.where(podcast_id: feed.podcast_id).pluck(:id)
      if Apple::DelegatedDeliveryConfig.where(feed_id: all_feeds).where.not(id: id).any?
        errors.add(:feed, "podcast already has an apple config")
      end
    end

    def publish_to_apple?
      !!routing_key&.valid? && publish_enabled?
    end

    def build_publisher
      Apple::Publisher.from_delegated_delivery_config(self)
    end

    def build_show
      Apple::Show.from_delegated_delivery_config(self)
    end

    def apple_key
      Base64.decode64(apple_key_pem_b64)
    end

    def apple_data
      episode_data = [
        SyncLog.apple.where(feeder_type: "episodes", feeder_id: podcast.episodes.pluck(:id)),
        Apple::PodcastContainer.where(episode: podcast.episodes)
      ].flatten.compact

      podcast_delivery_data = [
        Apple::PodcastDelivery.with_deleted.where(episode: podcast.episodes),
        Apple::PodcastDeliveryFile.with_deleted.where(episode: podcast.episodes)
      ]

      feed_data = [public_feed.apple_sync_log, private_feed.apple_sync_log].compact

      [podcast_delivery_data, episode_data, feed_data]
    end
  end
end
