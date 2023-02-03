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
    authorize @episode
  end

  # GET /episodes/new
  def new
    @episode = Episode.new(episode_params)
  end

  # GET /episodes/1/edit
  def edit
    authorize @episode, :show?
  end

  # POST /episodes
  def create
    @episode = Episode.new(episode_params)
    authorize @episode

    respond_to do |format|
      if @episode.save
        format.html { redirect_to episode_url(@episode), notice: t(".notice") }
      else
        flash.now[:error] = t(".error")
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /episodes/1
  def update
    @episode.assign_attributes(episode_params)
    authorize @episode

    respond_to do |format|
      if @episode.save
        format.html { redirect_to edit_episode_url(@episode), notice: t(".notice") }
      else
        flash.now[:error] = t(".error")
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /episodes/1
  def destroy
    authorize @episode
    @episode.destroy

    respond_to do |format|
      format.html { redirect_to episodes_url, notice: t(".notice") }
    end
  end

  private

  def set_episode
    @episode = Episode.find_by_guid!(params[:id])
  end

  def set_podcast
    if @episode
      @podcast = @episode.podcast
    elsif params[:podcast_id].present?
      @podcast = Podcast.find(params[:podcast_id])
      authorize @podcast, :show?
    end
  end

  def episode_params
    params.fetch(:episode, {}).permit(
      :title,
      :clean_title,
      :subtitle,
      :description,
      :summary,
      :production_notes,
      :explicit,
      :itunes_type,
      :season_number,
      :episode_number,
      :author_name,
      :author_email,
      :segment_count,
      categories: []
    )
  end
end
