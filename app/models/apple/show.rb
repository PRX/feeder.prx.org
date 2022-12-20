# frozen_string_literal: true

module Apple
  class Show
    attr_reader :public_feed,
                :private_feed,
                :api

    def self.connect_existing(apple_show_id, api, public_feed, private_feed)
      SyncLog.create!(feeder_id: public_feed.id,
                      feeder_type: :feeds,
                      sync_completed_at: Time.now.utc,
                      external_id: apple_show_id)

      new(api: api, public_feed: public_feed, private_feed: private_feed)
    end

    def self.get_episodes_json(api, show_id)
      api.get_paged_collection("shows/#{show_id}/episodes")
    end

    def self.get_show(api, show_id)
      resp = api.get("shows/#{show_id}")

      api.unwrap_response(resp)
    end

    def initialize(api:, public_feed:, private_feed:)
      @private_feed = private_feed
      @public_feed = public_feed
      @api = api
    end

    def reload
      # flush memoized attrs
      @get_episodes_json = nil
    end

    def podcast
      public_feed.podcast
    end

    def feed_published_url
      if public_feed.private?
        FeedToken.feed_published_url_with_token(public_feed)
      else
        public_feed.published_url
      end
    end

    def category_data
      podcast.itunes_categories.map { |c| { id: 1511, type: 'categories', attributes: { name: c.name } } }
      [{ 'type' => 'categories', 'id' => '1301' }]
    end

    def show_data
      {
        data: {
          type: 'shows',
          relationships: {
            allowedCountriesAndRegions: { data: api.countries_and_regions }
          },
          attributes: {
            kind: 'RSS',
            rssUrl: feed_published_url,
            releaseFrequency: 'OPTOUT',
            thirdPartyRights: 'HAS_RIGHTS_TO_THIRD_PARTY_CONTENT'
          }
        }
      }
    end

    def apple_id
      completed_sync_log&.external_id
    end

    def id
      apple_id
    end

    def completed_sync_log
      SyncLog.
        feeds.
        complete.
        where(feeder_id: public_feed.id, feeder_type: :feeds).
        order(created_at: :desc).first
    end

    def sync!
      last_completed_sync = completed_sync_log

      apple_json = create_or_update_show(last_completed_sync)

      SyncLog.create!(feeder_id: public_feed.id,
                      feeder_type: :feeds,
                      sync_completed_at: Time.now.utc,
                      external_id: apple_json['data']['id'])
    rescue Apple::ApiError => e
      SyncLog.create!(feeder_id: public_feed.id, feeder_type: :feeds)
    end

    def create_show!
      resp = api.post('shows', show_data)

      api.unwrap_response(resp)
    end

    def update_show!(sync)
      show_data_with_id = show_data
      show_data_with_id[:data][:id] = sync.external_id
      resp = api.patch("shows/#{sync.external_id}", show_data_with_id)

      api.unwrap_response(resp)
    end

    def create_or_update_show(sync)
      if sync.present?
        update_show!(sync)
      else
        create_show!
      end
    end

    def get_show
      raise 'Missing apple show id' unless apple_id.present?

      self.class.get_show(api, apple_id)
    end

    def get_episodes_json
      raise 'Missing apple show id' unless apple_id.present?

      @get_episodes_json ||=
        begin
          external_id = completed_sync_log&.external_id
          self.class.get_episodes_json(api, external_id)
        end
    end

    def apple_episodes_json
      get_episodes_json
    end
  end
end
