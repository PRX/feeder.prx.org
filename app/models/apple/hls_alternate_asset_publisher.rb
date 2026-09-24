# frozen_string_literal: true

module Apple
  # Reconciles each HLS-eligible episode in an Apple-crawled public feed with
  # Apple's alternate-asset state: patch the linked episode, patch the staged
  # asset, or stage a new one. Apple is the source of truth; results are
  # mirrored into Apple::HlsAlternateAsset.
  class HlsAlternateAssetPublisher
    include PodcastsHelper

    attr_reader :show_feed_binding, :feed, :show

    def self.publish!(show_feed_binding:, episodes:)
      new(show_feed_binding: show_feed_binding).publish!(episodes)
    end

    def initialize(show_feed_binding:)
      @show_feed_binding = show_feed_binding
      @feed = show_feed_binding.feed
      @show = Apple::Show.from_show_feed_binding(show_feed_binding)
    end

    def api
      show.api
    end

    # Bulk reads raise to the caller. Per-episode write failures are recorded
    # on the episode's mirror row and the run continues.
    def publish!(episodes)
      eligible = episodes.select(&:hls_eligible_for_apple?)
      return [] if eligible.empty?

      # Load bulk state here, outside publish_episode's rescue, so a failed
      # read raises instead of being recorded on every episode. Staged assets
      # are only needed for episodes Apple has not crawled yet.
      unlinked = eligible.reject { |episode| apple_episode_json(episode) }
      show.staged_alternate_asset_json if unlinked.any?

      eligible.map { |episode| publish_episode(episode) }
    end

    private

    def publish_episode(episode)
      guid = episode_guid(episode, feed)
      url = episode.apple_hls_master_url(feed: feed)

      if (episode_json = apple_episode_json(episode))
        publish_linked(episode, guid, url, episode_json)
      elsif (staged_json = show.find_staged_alternate_asset_json_by_guid(guid))
        publish_staged(episode, guid, url, staged_json)
      else
        stage(episode, guid, url)
      end
    rescue => error
      Rails.logger.error("Apple HLS alternate asset publish failed",
        {episode_id: episode.id, feed_id: feed.id, apple_show_id: show_feed_binding.apple_show_id, guid: guid, error: error})
      upsert(episode, guid, error: error)
    end

    def apple_episode_json(episode)
      show.find_apple_episode_json_by_guid(episode_guid(episode, feed))
    end

    # An archived Apple episode was hidden on purpose (or its unarchive
    # failed), so it is recorded as Apple reports it and left unpatched.
    def publish_linked(episode, guid, url, episode_json)
      if episode_json.dig("attributes", "publishingState") == "ARCHIVED"
        Rails.logger.error("Apple HLS linked episode is archived, skipping",
          {episode_id: episode.id, feed_id: feed.id, apple_show_id: show_feed_binding.apple_show_id, guid: guid, apple_episode_id: episode_json["id"]})
      elsif !alternate_asset_current?(episode_json, url)
        resp = api.patch("episodes/#{episode_json["id"]}", linked_episode_params(episode_json["id"], url))
        episode_json = api.response!(resp).dig("api_response", "val", "data")
      end

      upsert(episode, guid, resource_type: :episode, response: episode_json)
    end

    def publish_staged(episode, guid, url, staged_json)
      if staged_json.dig("attributes", "alternateAssetContentUrl") != url
        resp = api.patch("stagedAlternateAssets/#{staged_json["id"]}", staged_update_params(staged_json["id"], url))
        staged_json = api.response!(resp).dig("api_response", "val", "data")
      end

      upsert(episode, guid, resource_type: :staged_alternate_asset, response: staged_json)
    end

    # The create has no idempotency key, so it is sent once.
    def stage(episode, guid, url)
      log_vanished(episode, guid)

      resp = api.post("stagedAlternateAssets", staged_create_params(guid, url), tries: 1)
      staged_json = api.response!(resp).dig("api_response", "val", "data")

      upsert(episode, guid, resource_type: :staged_alternate_asset, response: staged_json)
    end

    # Apple no longer returns the resource a prior row recorded: staged assets
    # expire, but a linked episode should not disappear.
    def log_vanished(episode, guid)
      asset = Apple::HlsAlternateAsset.find_by(feeder_podcast_id: episode.podcast_id, apple_show_id: show_feed_binding.apple_show_id, feeder_guid: guid)
      context = {episode_id: episode.id, feed_id: feed.id, apple_show_id: show_feed_binding.apple_show_id, guid: guid}

      if asset&.linked?
        Rails.logger.warn("Apple HLS linked episode vanished, re-staging", context.merge(apple_episode_id: asset.apple_episode_id))
      elsif asset&.staged?
        Rails.logger.info("Apple HLS staged asset expired, re-staging", context.merge(staged_alternate_asset_id: asset.staged_alternate_asset_id))
      end
    end

    def upsert(episode, guid, **attrs)
      Apple::HlsAlternateAsset.upsert_from_apple!(episode: episode, show_feed_binding: show_feed_binding, feeder_guid: guid, **attrs)
    end

    def alternate_asset_attributes(url)
      {
        alternateAssetContentUrl: url,
        alternateAssetContentKind: Apple::HlsAlternateAsset::CONTENT_KIND,
        alternateAssetMimeType: Apple::HlsAlternateAsset::MIME_TYPE
      }
    end

    def alternate_asset_current?(episode_json, url)
      attributes = episode_json["attributes"] || {}
      alternate_asset_attributes(url).all? { |key, value| attributes[key.to_s] == value }
    end

    def linked_episode_params(apple_episode_id, url)
      {data: {type: "episodes", id: apple_episode_id, attributes: alternate_asset_attributes(url)}}
    end

    def staged_update_params(staged_id, url)
      {data: {type: "stagedAlternateAssets", id: staged_id, attributes: {alternateAssetContentUrl: url}}}
    end

    def staged_create_params(guid, url)
      {
        data: {
          type: "stagedAlternateAssets",
          attributes: alternate_asset_attributes(url).merge(guid: guid),
          relationships: {show: {data: {type: "shows", id: show.apple_id}}}
        }
      }
    end
  end
end
