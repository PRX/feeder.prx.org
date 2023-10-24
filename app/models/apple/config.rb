# frozen_string_literal: true

module Apple
  class Config < ApplicationRecord
    DEFAULT_FEED_SLUG = "apple-delegated-delivery-subscriptions"
    DEFAULT_TITLE = "Apple Delegated Delivery Subscriptions"
    DEFAULT_AUDIO_FORMAT = {"f" => "flac", "b" => 16, "c" => 2, "s" => 44100}.freeze

    belongs_to :public_feed, class_name: "Feed"
    belongs_to :private_feed, class_name: "Feed"

    belongs_to :key, class_name: "Apple::Key", optional: true

    has_one :podcast, through: :public_feed

    delegate :title, to: :podcast, prefix: "podcast"
    delegate :id, to: :podcast, prefix: "podcast"

    delegate :provider_id, to: :key
    delegate :key_id, to: :key
    delegate :key_pem, to: :key
    delegate :key_pem_b64, to: :key

    validates_presence_of :public_feed
    validates_presence_of :private_feed

    validates_associated :public_feed
    validates_associated :private_feed

    validates :public_feed, uniqueness: {scope: :private_feed,
                                         message: "can only have one config per public and private feed"}
    validates :public_feed, exclusion: {in: ->(apple_credential) { [apple_credential.private_feed] }}

    validate :one_config_per_podcast, on: :create
    validate :feed_podcasts_match

    def self.has_apple_config?(podcast)
      podcast.default_feed.apple_configs.present?
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

    def self.build_apple_config(podcast, key)
      if has_apple_config?(podcast)
        Rails.logger.error("Found existing apple config for #{podcast.title}!")
        Rails.logger.error("Do you want to continue? (y/N)")
        raise "Stopping build_apple_config" if $stdin.gets.chomp.downcase != "y"
      end

      ac = podcast.default_feed.apple_configs.first || Apple::Config.new
      ac.public_feed = podcast.default_feed
      ac.private_feed = find_or_build_private_feed(podcast)
      ac.key = key

      ac
    end

    def self.mark_as_delivered!(apple_publisher)
      apple_publisher.episodes_to_sync.each do |episode|
        if episode.podcast_container&.needs_delivery? == false
          episode.feeder_episode.apple_has_delivery!
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

    def one_config_per_podcast
      return unless public_feed.present? && private_feed.present?
      return unless podcast.present?

      if podcast.feeds.map(&:apple_configs).flatten.compact.present?
        errors.add(:podcast, "can only have one apple config")
      end
    end

    def feed_podcasts_match
      return unless public_feed.present? && private_feed.present?

      if public_feed.podcast != private_feed.podcast
        errors.add(:public_feed, "must belong to the same podcast as the private feed")
      end
    end

    def publish_to_apple?
      return false unless key&.valid?

      public_feed.publish_to_apple?(self)
    end

    def build_publisher
      Apple::Publisher.from_apple_config(self)
    end

    def apple_key
      Base64.decode64(apple_key_pem_b64)
    end

    def apple_data
      episode_data = [
        SyncLog.where(feeder_type: "episodes", feeder_id: podcast.episodes.pluck(:id)),
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
