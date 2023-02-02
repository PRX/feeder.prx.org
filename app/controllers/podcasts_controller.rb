class PodcastsController < ApplicationController
  before_action :set_podcast, only: %i[show edit update destroy]

  # GET /podcasts
  def index
    @podcasts = Podcast.all.limit(10)
  end

  # GET /podcasts/1
  def show
    authorize @podcast
  end

  # GET /podcasts/new
  def new
    @podcast = Podcast.new(podcast_params)
  end

  # GET /podcasts/1/edit
  def edit
    authorize @podcast, :show?
  end

  # POST /podcasts
  def create
    @podcast = Podcast.new(podcast_params)
    authorize @podcast

    respond_to do |format|
      if @podcast.save
        format.html { redirect_to podcast_url(@podcast), notice: t(".notice") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /podcasts/1
  def update
    @podcast.assign_attributes(podcast_params)
    authorize @podcast

    respond_to do |format|
      if @podcast.save
        format.html { redirect_to edit_podcast_url(@podcast), notice: t(".notice") }
      else
        flash.now[:error] = t(".error")
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /podcasts/1
  def destroy
    authorize @podcast
    @podcast.destroy

    respond_to do |format|
      format.html { redirect_to podcasts_url, notice: t(".notice") }
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:id])
  end

  def podcast_params
    params.fetch(:podcast, {}).permit(
      :title,
      :prx_account_uri,
      :subtitle,
      :description,
      :summary,
      :link,
      :explicit,
      :itunes_category,
      :itunes_subcategory,
      :serial_order,
      :language,
      :owner_name,
      :owner_email,
      :author_name,
      :author_email,
      :managing_editor_name,
      :managing_editor_email,
      :copyright,
      :complete
    )
  end
end
