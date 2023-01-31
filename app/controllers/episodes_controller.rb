class EpisodesController < ApplicationController
  before_action :set_episode, only: %i[show edit update destroy]
  before_action :set_podcast

  # GET /episodes
  def index
    @episodes =
      if params[:podcast_id]
        Podcast.find(params[:podcast_id]).episodes.all.limit(10)
      else
        Episode.all.limit(10)
      end
  end

  # GET /episodes/1
  def show
  end

  # GET /episodes/new
  def new
    @episode = Episode.new
  end

  # GET /episodes/1/edit
  def edit
  end

  # POST /episodes
  def create
    @episode = Episode.new(episode_params)

    respond_to do |format|
      if @episode.save
        format.html { redirect_to episode_url(@episode), notice: "Episode was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /episodes/1
  def update
    respond_to do |format|
      if @episode.update(episode_params)
        format.html { redirect_to episode_url(@episode), notice: "Episode was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /episodes/1
  def destroy
    @episode.destroy

    respond_to do |format|
      format.html { redirect_to episodes_url, notice: "Episode was successfully destroyed." }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_episode
    @episode = Episode.find(params[:id])
  end

  def set_podcast
    @podcast =
      if @episode
        @episode.podcast
      elsif params[:podcast_id].present?
        Podcast.find(params[:podcast_id])
      end
  end

  # Only allow a list of trusted parameters through.
  def episode_params
    params.fetch(:episode, {})
  end
end
