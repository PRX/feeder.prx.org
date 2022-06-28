# frozen_string_literal: true

class Apple::Show

  attr_reader :feed, :api

  def initialize(feed)
    @feed = feed
    @api = Apple::Api.from_env
  end

  def feed_published_url
    raise 'Missing auth tokens for private feed' if feed.private? && feed.tokens.length == 0

    if feed.private?
      feed.tokens.first.feed_published_url_with_token
    else
      feed.published_url
    end
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

  def completed_sync_log
    SyncLog.
      feeds.
      complete.
      where(feeder_id: feed.id, feeder_type: 'f').
      order(created_at: :desc).first
  end

  def sync!
    last_completed_sync = completed_sync_log

    json = create_or_update_show(last_completed_sync)

    sync = SyncLog.create!(feeder_id: feed.id,
                           feeder_type: 'f',
                           sync_completed_at: Time.now.utc,
                           external_id: json['data']['id'])

  rescue Apple::ApiError => e
    sync = SyncLog.create!(feeder_id: feed.id, feeder_type: 'f')
  end

  def create_show!(sync)
    resp = api.post('shows', show_data)

    api.unwrap_response(resp)
  end

  def update_show!(show, sync)
  end

  def create_or_update_show(sync)
    if sync.present?
      show = get_show(sync.external_id)
      update_show!(show, sync)
    else
      create_show!(sync)
    end
  end

  def get_show(show_id)
    resp = api.get("show/#{show_id}")

    api.unwrap_response(resp.body)
  end
end
