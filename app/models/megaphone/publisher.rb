module Megaphone
  class Publisher < Integrations::Base::Publisher
    WAIT_INTERVAL = 5.seconds
    WAIT_TIMEOUT = 5.minutes

    attr_reader :feed
    attr_accessor :wait_interval

    def initialize(feed)
      @feed = feed
      @wait_interval = WAIT_INTERVAL
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
        delete_episodes!

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
      episodes = private_feed.episodes.unfinished(:megaphone)
      timeout_at = Time.now.utc + WAIT_TIMEOUT

      while episodes.size > 0 && Time.now.utc < timeout_at
        sleep(wait_interval)
        episodes = check_episodes(episodes)
      end

      # if after all those checks, still incomplete? throw an error
      if episodes.size > 0
        msg = "Megaphone::Publisher.check_status_episodes! timed out on: #{episodes.map(&:id)}"
        Rails.logger.error(msg)
        raise msg
      end
    end

    def check_episodes(episodes)
      remaining = []

      episodes.each do |ep|
        megaphone_episode = Megaphone::Episode.find_by_episode(megaphone_podcast, ep)

        # check if it is uploaded yet
        # if not go looking for the DTR media version
        status = megaphone_episode.delivery_status
        if !status.uploaded?
          megaphone_episode.upload_audio!
        # check if it is uploaded, but not delivered - see if megaphone has processed
        elsif !status.delivered?
          megaphone_episode.check_audio!
        end

        # make sure we get the latest status on the episode
        ep.reload
        episode_status = ep.episode_delivery_status(:megaphone)
        if !episode_status.delivered? || !episode_status.uploaded?
          remaining << ep
        end
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

    def delete_episodes!
      megaphone_episodes = []
      podcast.episodes.with_deleted.where.not(id: private_feed.episodes).each do |ep|
        next unless ep.episode_delivery_status(:megaphone).present?
        if (megaphone_episode = Megaphone::Episode.find_by_episode(megaphone_podcast, ep))
          megaphone_episode.delete!
          megaphone_episodes << megaphone_episode
        end
      end
      megaphone_episodes
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
