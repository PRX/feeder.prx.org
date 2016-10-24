class PodcastsController < ApplicationController
  def show
    @podcast = Podcast.find(podcast_params)

    if stale?(last_modified: @podcast.last_build_date.utc, etag: @podcast.cache_key)
      @episodes = @podcast.feed_episodes
    end
  end

  private

  def podcast_params
    params.permit(:id).require(:id)
  end
end
