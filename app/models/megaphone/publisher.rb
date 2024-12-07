module Megaphone
  class Publisher < Integrations::Base::Publisher
    attr_reader :feed

    def initialize(feed)
      @feed = feed
    end

    def megaphone_podcast
      @megaphone_podcast ||= Megaphone::Podcast.find_by_feed(feed)
    end

    alias_method :show, :megaphone_podcast
    alias_method :private_feed, :feed

    def publish!
      sync_podcast!
      sync_episodes!

      # success
      SyncLog.log!(
        integration: :megaphone,
        feeder_id: public_feed.id,
        feeder_type: :feeds,
        external_id: megaphone_podcast.id,
        api_response: {success: true}
      )
    end

    def sync_episodes!
      Rails.logger.tagged("Megaphone::Publisher#sync_episodes!") do
        # start with drafts, make sure they have been at least created
        private_feed.episodes.unfinished(:megaphone).each do |ep|
          # see if we can find it by guid or megaphone id
          if (megaphone_episode = Megaphone::Episode.find_by_episode(megaphone_podcast, ep))
            megaphone_episode.update!(ep)
          end

          megaphone_episode ||= Megaphone::Episode.new_from_episode(megaphone_podcast, ep).create!

          SyncLog.log!(
            integration: :megaphone,
            feeder_id: ep.id,
            feeder_type: :episodes,
            external_id: megaphone_episode.id,
            api_response: megaphone_episode.api_response_log_item
          )
        end
      end
    end

    def sync_podcast!
      # see if we need to update by comparing dates
      # - there is no episode delivery status ;)
      if megaphone_podcast && (megaphone_podcast.updated_at < podcast.updated_at)
        megaphone_podcast.update!(feed)
      end

      # if that didn't find & update a podcast, create it and set it
      @megaphone_podcast ||= Megaphone::Podcast.new_from_feed(feed).create!

      SyncLog.log!(
        integration: :megaphone,
        feeder_id: public_feed.id,
        feeder_type: :feeds,
        external_id: megaphone_podcast.id,
        api_response: megaphone_podcast.api_response_log_item
      )
      megaphone_podcast
    end

    def config
      feed&.config
    end

    def public_feed
      podcast&.public_feed
    end

    def podcast
      feed&.podcast
    end
  end
end
