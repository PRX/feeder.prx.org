class PodcastsController < ApplicationController
  before_action :set_podcast, only: %i[show edit update destroy]

  # Translate the user selected sort to a query order argument
  DISPLAY_ORDER = {"A-Z" => {title: :asc},
                   "Z-A" => {title: :desc},
                   "" => {updated_at: :desc}}.freeze

  DEFAULT_PAGE_SIZE = 10

  # GET /podcasts
  def index
    base_query = policy_scope(Podcast).page(params[:page]).per(DEFAULT_PAGE_SIZE)
    @podcasts = add_sorting(base_query)
  end

  def add_sorting(query)
    if params[:sort] == "episode_count"
      query.left_joins(:episodes).group(:id).order("COUNT(episodes.id) DESC")
    else
      query.order(DISPLAY_ORDER[params[:sort].to_s])
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
end
