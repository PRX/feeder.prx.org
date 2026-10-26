# frozen_string_literal: true

module Apple
  # Defaults for a new private feed that delivers to Apple Subscriptions,
  # carried over from the old Feeds::AppleSubscription. Values already set
  # on the feed are kept, except that the feed is always private.
  #
  #   Apple::DeliveryFeedDefaults.new(feed).assign
  class DeliveryFeedDefaults
    SLUG = "apple-delegated-delivery-subscriptions"
    ZONES = ["billboard", "sonic_id"].freeze
    AUDIO_FORMAT = {f: "mp3", b: 128, c: 2, s: 44100}.freeze

    # Apple's minimum mp3 settings, for mono or stereo.
    # https://podcasters.apple.com/support/893-audio-requirements
    MIN_MP3_BITRATE = 64
    MP3_CHANNELS = [1, 2].freeze
    MIN_MP3_SAMPLERATE = 44100

    attr_reader :feed

    def initialize(feed)
      @feed = feed
    end

    def assign
      feed.slug = slug if feed.slug.blank?
      feed[:label] ||= Apple::DelegatedDeliveryConfig::DEFAULT_TOKEN_LABEL
      feed.private = true
      feed.display_episodes_count ||= podcast&.default_feed&.display_episodes_count
      feed.include_zones ||= ZONES.dup
      feed.audio_format ||= audio_format
      feed
    end

    # The first free Apple Subscriptions slug, since a podcast can have one
    # delivery feed per connected public feed.
    def slug
      return SLUG unless feed.podcast_id

      taken = Feed.unscoped.where(podcast_id: feed.podcast_id).where("slug LIKE ?", "#{SLUG}%").pluck(:slug)
      candidate = SLUG
      suffix = 1
      candidate = "#{SLUG}-#{suffix += 1}" while taken.include?(candidate)
      candidate
    end

    # The default feed's mp3 format, else the highest of the recent published
    # mp3 episodes, raised to Apple's minimums.
    def audio_format
      default_format = podcast&.default_feed&.audio_format
      format = default_format if default_format && default_format[:f] == "mp3"
      format ||= episode_audio_format
      format ? standardize(format) : AUDIO_FORMAT.dup.with_indifferent_access
    end

    private

    def podcast
      feed.podcast
    end

    def episode_audio_format
      episodes = podcast&.episodes&.published&.includes(:contents)&.limit(10) || []
      # Mirror the publisher, which only syncs audio? episodes to Apple
      # (Integrations::Base::EpisodeSetOperations#filter_episodes_to_sync)
      contents = episodes.select(&:audio?).map { |episode| episode.contents.first }.compact
      mp3_contents = contents.select { |content| content.audio? && content.mime_type == "audio/mpeg" }
      return if mp3_contents.empty?

      {
        b: mp3_contents.map { |content| content.bit_rate.to_i }.max,
        c: mp3_contents.map { |content| content.channels.to_i }.max,
        s: mp3_contents.map { |content| content.sample_rate.to_i }.max
      }
    end

    def standardize(format)
      {
        f: "mp3",
        b: [MIN_MP3_BITRATE, format[:b]].compact.max,
        c: MP3_CHANNELS.include?(format[:c]) ? format[:c] : MP3_CHANNELS.min,
        s: [MIN_MP3_SAMPLERATE, format[:s]].compact.max
      }.with_indifferent_access
    end
  end
end
