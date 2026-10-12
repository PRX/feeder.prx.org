# frozen_string_literal: true

module Apple
  # Reconciles each HLS-eligible episode in an Apple-crawled public feed with
  # Apple's alternate-asset state: patch the linked episode, patch the staged
  # asset, or stage a new one. Apple is the source of truth; results are
  # mirrored into Apple::HlsAlternateAsset.
  class HlsAlternateAssetPublisher
    include PodcastsHelper
    extend PodcastsHelper

    attr_reader :show_feed_binding, :feed, :show

    def self.publish!(show_feed_binding:, episodes:)
      new(show_feed_binding: show_feed_binding).publish!(episodes)
    end

    def self.poll!(episode, show_feed_binding:)
      new(show_feed_binding: show_feed_binding).poll!(episode)
    end

    # The producer-facing HLS status for an episode in an Apple-bound feed,
    # read from the local mirror. Nil when the feed has no enabled HLS config.
    def self.status_for(episode, feed:)
      hls_config = feed.apple_show_feed_binding&.hls_config
      return unless hls_config&.enabled?
      return :not_eligible if hls_config.not_eligible?
      return :failed if episode.hls_failed_for_apple?

      asset = asset_for(episode, feed: feed)
      in_rss = feed.rss_episode?(episode)
      if asset && (asset.linked? || in_rss)
        asset.status.to_sym
      elsif (in_rss || episode.published?) && episode.hls_processing_for_apple?
        :processing
      elsif !in_rss
        :not_published
      elsif episode.hls_eligible_for_apple?
        :pending
      else
        :not_eligible
      end
    end

    def self.asset_for(episode, feed:)
      Apple::HlsAlternateAsset.find_by(
        feeder_podcast_id: episode.podcast_id,
        apple_show_id: feed.apple_show_feed_binding.apple_show_id,
        feeder_guid: episode_guid(episode, feed)
      )
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

      unlinked = eligible.reject { |episode| apple_episode_json(episode) }
      show.staged_alternate_asset_json if unlinked.any?

      eligible.map { |episode| publish_episode(episode) }
    end

    def poll!(episode)
      started_at = Time.current
      guid = episode_guid(episode, feed)
      asset = self.class.asset_for(episode, feed: feed)
      episode_json = show.find_apple_episode_json_by_guid_filter(guid) ||
        (show.find_apple_episode_json_by_apple_id(guid) if asset&.apple_episode_id == guid)

      attrs = if episode_json
        # Apple ingested the episode with only its audio; the next publish
        # patches it, so it stays pending rather than an error.
        return if asset.nil? && episode_json.dig("attributes", "alternateAssetContentUrl").blank?

        {resource_type: :episode, response: episode_json}
      elsif (staged_json = show.find_staged_alternate_asset_json_by_guid_filter(guid))
        {resource_type: :staged_alternate_asset, response: staged_json}
      else
        {}
      end
      upsert(episode, guid, **attrs, unless_checked_after: started_at)
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

    def publish_linked(episode, guid, url, episode_json)
      if episode_json.dig("attributes", "publishingState") == "ARCHIVED"
        Rails.logger.error("Apple HLS linked episode is archived, skipping",
          {episode_id: episode.id, feed_id: feed.id, apple_show_id: show_feed_binding.apple_show_id, guid: guid, apple_episode_id: episode_json["id"]})
      elsif !Apple::HlsAlternateAsset.current_on_apple?(episode_json, url)
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

    def stage(episode, guid, url)
      log_vanished(episode, guid)

      resp = api.post("stagedAlternateAssets", staged_create_params(guid, url), tries: 1)
      staged_json = api.response!(resp).dig("api_response", "val", "data")

      upsert(episode, guid, resource_type: :staged_alternate_asset, response: staged_json)
    end

    def log_vanished(episode, guid)
      asset = Apple::HlsAlternateAsset.find_by(feeder_podcast_id: episode.podcast_id, apple_show_id: show_feed_binding.apple_show_id, feeder_guid: guid)
      context = {episode_id: episode.id, feed_id: feed.id, apple_show_id: show_feed_binding.apple_show_id, guid: guid}

      if asset&.linked?
        Rails.logger.warn("Apple HLS linked episode vanished, re-staging", context.merge(apple_episode_id: asset.apple_episode_id))
      elsif asset&.staged? || asset&.expired?
        Rails.logger.info("Apple HLS staged asset expired, re-staging", context.merge(staged_alternate_asset_id: asset.staged_alternate_asset_id))
      end
    end

    def upsert(episode, guid, **attrs)
      Apple::HlsAlternateAsset.upsert_from_apple!(episode: episode, show_feed_binding: show_feed_binding, feeder_guid: guid, **attrs)
    end

    def linked_episode_params(apple_episode_id, url)
      {data: {type: "episodes", id: apple_episode_id, attributes: Apple::HlsAlternateAsset.apple_attributes(url)}}
    end

    def staged_update_params(staged_id, url)
      {data: {type: "stagedAlternateAssets", id: staged_id, attributes: {alternateAssetContentUrl: url}}}
    end

    def staged_create_params(guid, url)
      {
        data: {
          type: "stagedAlternateAssets",
          attributes: Apple::HlsAlternateAsset.apple_attributes(url).merge(guid: guid),
          relationships: {show: {data: {type: "shows", id: show.apple_id}}}
        }
      }
    end
  end
end
