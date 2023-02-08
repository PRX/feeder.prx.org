class PodcastsController < ApplicationController
  before_action :set_podcast, only: %i[show edit update destroy]

  # GET /podcasts
  def index
    @podcasts = Podcast.all.limit(10)
    @podcasts = get_podcasts
  end

  # GET /podcasts/1
  def show
  end

  # GET /podcasts/new
  def new
    @podcast = Podcast.new
  end

  # GET /podcasts/1/edit
  def edit
  end

  # POST /podcasts
  def create
    @podcast = Podcast.new(podcast_params)

    respond_to do |format|
      if @podcast.save
        format.html { redirect_to podcast_url(@podcast), notice: "Podcast was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /podcasts/1
  def update
    respond_to do |format|
      if @podcast.update(podcast_params)
        format.html { redirect_to podcast_url(@podcast), notice: "Podcast was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /podcasts/1
  def destroy
    @podcast.destroy

    respond_to do |format|
      format.html { redirect_to podcasts_url, notice: "Podcast was successfully destroyed." }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def get_podcasts
    if params[:sort] == '# of Episodes'
      policy_scope(Podcast).order(updated_at: :asc).limit(10)
    elsif params[:sort] == 'A-Z'
      policy_scope(Podcast).order(title: :asc).limit(10)
    elsif params[:sort] == 'Z-A'
      policy_scope(Podcast).order(title: :desc).limit(10)
    else
      policy_scope(Podcast).order(updated_at: :desc).limit(10)
    end
  end
  
  def set_podcast
    @podcast = Podcast.find(params[:id])
  end
  
  # Only allow a list of trusted parameters through.
  def podcast_params
    params.fetch(:podcast, {})
  end
end
