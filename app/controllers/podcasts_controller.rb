class PodcastsController < ApplicationController
  def show
    @podcast = Podcast.find(podcast_params)
    @categories = @podcast.itunes_categories
    episodes = @podcast.episodes.order('created_at desc')

    @episodes = episodes.map do |e|
      EpisodeBuilder.from_prx_story(prx_id: e.prx_id,
                                    overrides: e.overrides)
    end
  end

  private

  def podcast_params
    params.permit(:id).require(:id)
  end
end
