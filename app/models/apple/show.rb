# frozen_string_literal: true

module Apple
  class Show
    attr_reader :feed, :api

    def initialize(feed)
      @feed = feed
      @api = Apple::Api.from_env
    end

    def reload
      # flush memoized attrs
      @get_episodes = nil
    end

    def podcast
      feed.podcast
    end

    def feed_published_url
      podcast_default_feed = feed.podcast.default_feed

      if podcast_default_feed.private? && podcast_default_feed.tokens.empty?
        raise "Missing auth tokens for private feed"
      end

      if podcast_default_feed.private?
        podcast_default_feed.tokens.first.feed_published_url_with_token
      else
        podcast_default_feed.published_url
      end
    end

    def category_data
      podcast.itunes_categories.map { |c| { id: 1511, type: "categories", attributes: { name: c.name } } }
      [{ "type" => "categories", "id" => "1301" }]
    end

    def show_data
      {
        data: {
          type: "shows",
          relationships: {
            allowedCountriesAndRegions: { data: api.countries_and_regions },
          },
          attributes: {
            kind: "RSS",
            rssUrl: feed_published_url,
            releaseFrequency: "OPTOUT",
            thirdPartyRights: "HAS_RIGHTS_TO_THIRD_PARTY_CONTENT",
          }
        }
      }
    end

    def id
      completed_sync_log&.external_id
    end

    def completed_sync_log
      SyncLog.
        feeds.
        complete.
        where(feeder_id: feed.id, feeder_type: :feeds).
        order(created_at: :desc).first
    end

    def sync!
      last_completed_sync = completed_sync_log

      apple_json = create_or_update_show(last_completed_sync)

      SyncLog.create!(feeder_id: feed.id,
                      feeder_type: :feeds,
                      sync_completed_at: Time.now.utc,
                      external_id: apple_json["data"]["id"])
    rescue Apple::ApiError => e
      puts e
      SyncLog.create!(feeder_id: feed.id, feeder_type: :feeds)
    end

    def create_show!(_sync)
      resp = api.post("shows", show_data)

      api.unwrap_response(resp)
    end

    def update_show!(sync)
      show_data_with_id = show_data
      show_data_with_id[:data][:id] = sync.external_id
      resp = api.patch("shows/" + sync.external_id, show_data_with_id)

      api.unwrap_response(resp)
    end

    def create_or_update_show(sync)
      if sync.present?
        update_show!(sync)
      else
        create_show!(sync)
      end
    end

    def get_show
      return nil unless id.present?

      self.class.get_show(api, id)
    end

    def get_episodes
      @get_episodes ||=
        begin
          external_id = completed_sync_log&.external_id
          self.class.get_episodes(api, external_id)
        end
    end

    def apple_episodes
      get_episodes
    end

    def self.get_show(api, show_id)
      resp = api.get("shows/#{show_id}")

      api.unwrap_response(resp)
    end

    def self.get_episodes(api, show_id)
      api.get_paged_collection("shows/#{show_id}/episodes")
    end
  end
end
