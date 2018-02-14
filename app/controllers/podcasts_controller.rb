class PodcastsController < ApplicationController
  def show
    @podcast = Podcast.find(podcast_params)

    if @podcast.locked?
      redirect_to published_url
    else
      if stale?(last_modified: @podcast.updated_at.utc, etag: @podcast.cache_key)
        @episodes = @podcast.feed_episodes
      end
    end
  end

  private

  def podcast_params
    params.permit(:id).require(:id)
  end
end
