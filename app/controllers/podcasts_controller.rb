class PodcastsController < ApplicationController
  def show
    @podcast = Podcast.find(podcast_params)
    @feed = @podcast.default_feed

    if @podcast.locked? && !params[:unlock]
      redirect_to @podcast.published_url, allow_other_host: true
    elsif stale?(last_modified: @podcast.updated_at.utc, etag: @podcast.cache_key)
      @episodes = @podcast.feed_episodes
      @feed_image = @feed.feed_image || @podcast.feed_image
      @itunes_image = @feed.itunes_image || @podcast.itunes_image
    end
  end

  private

  def podcast_params
    params.permit(:id).require(:id)
  end
end
