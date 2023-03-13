class PodcastsController < ApplicationController
  before_action :set_podcast, only: %i[show edit update destroy]

  # GET /podcasts

  def index
    @podcasts = Podcast.order(:id).page params[:page]

      if params[:podcast_params]
        policy_scope(Podcast).find(params[:podcast_params]).get_podcasts.paginate(page: params[:page], per_page: 10)
      else
        policy_scope(Podcast).all
      end
  end
end

  # GET /podcasts/1
  def show
    authorize @podcast

    @recently_published = @podcast.episodes.published.first
    @next_scheduled = @podcast.episodes.draft_or_scheduled.order(:released_at).first
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
        flash.now[:error] = t(".error")
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

    respond_to do |format|
      # TODO: better/real validation?
      if @podcast.episodes.published_by(10.years).any?
        flash.now[:error] = t(".error")
        format.html { render :edit, status: :unprocessable_entity }
      else
        @podcast.destroy
        format.html { redirect_to podcasts_url, notice: t(".notice") }
      end
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

  # Use callbacks to share common setup or constraints between actions.
  def get_podcasts
    if params[:sort] == "# of Episodes"
      policy_scope(Podcast).order(updated_at: :asc).limit(10)
    elsif params[:sort] == "A-Z"
      policy_scope(Podcast).order(title: :asc).limit(10)
    elsif params[:sort] == "Z-A"
      policy_scope(Podcast).order(title: :desc).limit(10)
    else
      policy_scope(Podcast).order(updated_at: :desc).limit(10)
    end
  end
