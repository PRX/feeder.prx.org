module Megaphone
  class Episode < Megaphone::Model
    attr_accessor :episode

    # Required attributes for a create
    # external_id is not required by megaphone, but we need it to be set!
    CREATE_REQUIRED = %w[title external_id]

    CREATE_ATTRIBUTES = CREATE_REQUIRED + %w[pubdate pubdate_timezone author link explicit draft
      subtitle summary background_image_file_url background_audio_file_url pre_count post_count
      insertion_points guid pre_offset post_offset expected_adhash original_filename original_url
      episode_number season_number retain_ad_locations advertising_tags]

    # All other attributes we might expect back from the Megaphone API
    # (some documented, others not so much)
    OTHER_ATTRIBUTES = %w[id created_at updated_at]

    DEPRECATED = %w[]

    ALL_ATTRIBUTES = (CREATE_REQUIRED + DEPRECATED + OTHER_ATTRIBUTES)

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    validates_presence_of :id, on: :update

    validates_absence_of :id, on: :create

    def self.new_from_episode(dt_episode, feed = nil)
      episode = Megaphone::Episode.new(attributes_from_episode(dt_episode))
      episode.episode = dt_episode
      episode.feed = feed
      episode.set_audio_attributes
      episode
    end

    def self.attributes_from_episode(e)
      {
        title: e.title,
        external_id: e.guid,
        guid: e.item_guid,
        pubdate: e.published_at,
        pubdate_timezone: e.published_at.zone,
        author: e.author_name,
        link: e.url,
        explicit: e.explicit,
        draft: e.draft?,
        subtitle: e.subtitle,
        summary: e.description,
        background_image_file_url: e.ready_image&.href,
        episode_number: e.episode_number,
        season_number: e.season_number,
        advertising_tags: e.categories
        # pre_count: e.pre_count,
        # post_count: e.post_count,
        # expected_adhash: e.expected_adhash,
        # original_filename: e.original_filename,
        # original_url: e.original_url,
      }
    end

    def set_audio_attributes
      return unless episode.feed_ready?
      self.background_audio_file_url = enclosure_url
      self.insertion_points = timings
      self.retain_ad_locations = true
    end

    def enclosure_url
      url = EnclosureUrlBuilder.new.base_enclosure_url(episode.podcast, episode, feed)
      EnclosureUrlBuilder.mark_authorized(url, feed)
    end

    def timings
      episode.media[0..-2].map(&:duration)
    end
  end
end
