# frozen_string_literal: true

class Apple::Show

  attr_reader :feed, :api

  def initialize(feed)
    @feed = feed
    @api = Apple::Api.from_env
  end

  def podcast
    feed.podcast
  end

  def feed_published_url
    podcast_default_feed = feed.podcast.default_feed

    if podcast_default_feed.private? && podcast_default_feed.tokens.empty?
      raise 'Missing auth tokens for private feed'
    end

    if podcast_default_feed.private?
      podcast_default_feed.tokens.first.feed_published_url_with_token
    else
      podcast_default_feed.published_url
    end
  end

  def category_data
    podcast.itunes_categories.map { |c| {id: 1511, type: 'categories',  attributes: { name: c.name}} }
    [{"type"=>"categories", "id"=>"1301"}]
  end

  def show_data
    {
      data: {
        type: 'shows',
        relationships: {
          allowedCountriesAndRegions: {data: api.countries_and_regions},
        },
        attributes: {
          kind: 'RSS',
          rssUrl: feed_published_url,
          releaseFrequency: 'OPTOUT',
          thirdPartyRights: 'HAS_RIGHTS_TO_THIRD_PARTY_CONTENT',
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
      where(feeder_id: feed.id, feeder_type: 'f').
      order(created_at: :desc).first
  end

  def sync!
    last_completed_sync = completed_sync_log

    apple_json = create_or_update_show(last_completed_sync)

    sync = SyncLog.create!(feeder_id: feed.id,
                           feeder_type: 'f',
                           sync_completed_at: Time.now.utc,
                           external_id: apple_json['data']['id'])

  rescue Apple::ApiError => e
    puts e
    sync = SyncLog.create!(feeder_id: feed.id, feeder_type: 'f')
  end

  def create_show!(_sync)
    resp = api.post('shows', show_data)

    api.unwrap_response(resp)
  end

  def update_show!(sync)
    show_data_with_id = show_data
    show_data_with_id[:data][:id] = sync.external_id
    resp = api.patch('shows/' + sync.external_id, show_data_with_id)

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
    external_id = completed_sync_log&.external_id
    self.class.get_episodes(api, external_id)
  end

  def get_episode_asset_container_metadata
    get_episodes.map do |ep|
      vendor_id = ep['attributes']['appleHostedAudioAssetVendorId']

      {
        apple_episode_id: ep['id'],
        audio_asset_vendor_id: vendor_id,
        podcast_containers_url: episode_podcast_container_url(vendor_id)
      }
    end
  end

  def episode_podcast_container_url(vendor_id)
      api.join_url('podcastContainers?filter[vendorId]=' + vendor_id).to_s
  end

  def get_podcast_containers

    resp =
      api.bridge_get('podcastContainers', get_episode_asset_container_metadata)

    binding.pry

    api.unwrap_response(resp)
  end

  def self.get_show(api, show_id)
    resp = api.get("shows/#{show_id}")

    api.unwrap_response(resp)
  end

  def self.get_episodes(api, show_id)
    api.get_paged_collection("shows/#{show_id}/episodes")
  end
end
