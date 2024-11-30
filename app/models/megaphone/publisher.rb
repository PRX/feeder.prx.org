module Megaphone
  class Publisher < Integrations::Base::Publisher
    attr_reader :feed, :megaphone_podcast

    alias_method :private_feed, :feed

    def initialize(feed)
      @feed = feed
    end

    def show
      @megaphone_podcast ||= Megaphone::Podcast.find_by_feed(feed)
    end

    def publish!
      sync_podcast!
      raise "Missing Megaphone Podcast!" unless megaphone_podcast&.id.present?

      # success
      SyncLog.log!(
        integration: :megaphone,
        feeder_id: public_feed.id,
        feeder_type: :feeds,
        external_id: megaphone_podcast.id,
        api_response: {success: true}
      )
    end

    def deliver_and_publish!
      episodes = episodes_to_sync
      puts "deliver_and_publish!: #{episodes.count}"
    end

    def sync_podcast!
      if (@megaphone_podcast = Megaphone::Podcast.find_by_feed(feed))
        # see if we need to update by comparing dates
        # - there is no episode delivery status ;)
        if @megaphone_podcast.updated_at < podcast.updated_at
          @megaphone_podcast.update!(feed)
        end
      end

      @megaphone_podcast ||= if @megaphone_podcast.blank?
        Megaphone::Podcast.new_from_feed(feed).create!
      end

      SyncLog.log!(
        integration: :megaphone,
        feeder_id: public_feed.id,
        feeder_type: :feeds,
        external_id: @megaphone_podcast.id,
        api_response: @megaphone_podcast.api_response_log_item
      )
      @megaphone_podcast
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
