class PodcastSwitcherController < ApplicationController
  layout false

  # GET /podcast_switcher
  # lazy initial loading of podcast switcher
  def show
    @podcast_switcher_count = count_podcasts
    @podcast_switcher_podcasts = get_podcasts
  end

  # POST /podcast_switcher
  # turbo stream querying for podcasts
  def create
    @podcast_switcher_count = count_podcasts
    @podcast_switcher_podcasts = search_podcasts

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def count_podcasts
    policy_scope(Podcast).count
  end

  def get_podcasts
    policy_scope(Podcast).order(updated_at: :desc).limit(5)
  end

  def search_podcasts
    if params[:q].present?
      get_podcasts.where("title ILIKE ?", "%#{params[:q]}%")
    else
      get_podcasts
    end
  end
end
