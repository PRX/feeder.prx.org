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
    end

    def sync_episodes!
      Rails.logger.tagged("Megaphone::Publisher#sync_episodes!") do
        # delete or unpublish episodes we aren't including in the feed anymore
        unpublish_and_delete_episodes!

        # start with create and update, make sure they have been created at least
        create_and_update_episodes!

        # check if the upload has completed and the audio has finished processing
        check_status_episodes!
      end
    end

    # For status
    # :uploaded = the latest media version was ready on dtr, and was saved to mp
    # :delivered = attributes saved, media finished processing
    # if not uploaded, and media ready, try to set that on the next update
    # if uploaded and not delivered, check mp status, see if processing done
    def check_status_episodes!
      private_feed.episodes.unfinished(:megaphone).each do |ep|
        megaphone_episode = Megaphone::Episode.find_by_episode(megaphone_podcast, ep)
        next unless megaphone_episode
      end
    end

    def create_and_update_episodes!
      megaphone_episodes = []
      private_feed.episodes.unfinished(:megaphone).each do |ep|
        # see if we can find it by guid or megaphone id
        if (megaphone_episode = Megaphone::Episode.find_by_episode(megaphone_podcast, ep))
          megaphone_episode.update!(ep)
        end
        megaphone_episode ||= create_episode!(megaphone_podcast, ep)
        megaphone_episodes << megaphone_episode
      end

      megaphone_episodes
    end

    def create_episode!(megaphone_podcast, ep)
      me = Megaphone::Episode.new_from_episode(megaphone_podcast, ep)
      me.create!
    end

    def unpublish_and_delete_episodes!
    end

    def sync_podcast!
      Rails.logger.tagged("Megaphone::Publisher#sync_podcast!") do
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
