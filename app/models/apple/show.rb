# frozen_string_literal: true

class Apple::Show

  attr_reader :feed, :api

  def initialize(feed)

    @feed = feed
    @api = Apple::Api.from_env
  end

  def find_or_create_active_sync_log
    sync = SyncLog.
      feeds.
      complete.
      where(feeder_id: feed.id, feeder_type: 'f').
      order(created_at: :desc).first

    sync = SyncLog.create!(feeder_id: feed.id, feeder_type: 'f') unless sync.present?

    sync
  end

  def sync!
    sync = find_or_create_active_sync_log

    create_res = create_or_update_show(sync)

    binding.pry

    sync
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
          rssUrl: feed.published_url,
          releaseFrequency: 'OPTOUT',
          thirdPartyRights: 'HAS_RIGHTS_TO_THIRD_PARTY_CONTENT',
        }
      }
    }
  end

  def create_show!(sync)
    api.post('shows', show_data)
  end

  def update_show!(show, sync)
  end

  def create_or_update_show(sync)
    if sync.external_id
      show = get_show(sync.external_id)
      update_show!(show, sync)
    else
      create_show!(sync)
    end
  end

  def get_show(show_id)
    resp = api.get("show/#{show_id}")

    JSON.parse(resp.body)
  end
end
