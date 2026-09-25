class EpisodeAppleHlsStatusesController < ApplicationController
  before_action :set_episode

  # GET /episodes/1/apple_hls_status
  def show
    authorize @episode, :show?

    @feeds = helpers.episode_apple_hls_feeds(@episode)
    @feeds.each { |feed| poll(feed) }

    render layout: false
  end

  private

  def set_episode
    @episode = Episode.find_by_guid!(params[:episode_id])
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  # Best-effort refresh from Apple; on failure the mirror row is unchanged
  # and the serialized status renders.
  def poll(feed)
    return unless feed.apple_hls_config.publishable?
    return unless @episode.hls_eligible_for_apple? || Apple::HlsAlternateAssetPublisher.asset_for(@episode, feed: feed)

    Apple::HlsAlternateAssetPublisher.poll!(@episode, show_feed_binding: feed.apple_show_feed_binding)
  rescue => e
    Rails.logger.error("Apple HLS status poll failed", {episode_id: @episode.id, feed_id: feed.id, error: e})
  end
end
