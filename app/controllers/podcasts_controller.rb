class PodcastsController < ApplicationController
  include PrxAccess

  before_action :set_podcast, only: %i[show edit update destroy]

  # Translate the user selected sort to a query order argument
  DISPLAY_ORDER = {"A-Z" => {title: :asc},
                   "Z-A" => {title: :desc},
                   "" => {updated_at: :desc},
                   "Recent Activity" => {updated_at: :desc}}.freeze

  DEFAULT_PAGE_SIZE = 10

  # GET /podcasts
  def index
    base_query = policy_scope(Podcast).page(params[:page]).per(DEFAULT_PAGE_SIZE).includes(default_feed: :feed_images)
    filtered_podcasts = if params[:q].present?
      base_query.filter_by_title(params[:q])
    else
      base_query
    end
    @podcasts = add_sorting(filtered_podcasts)

    @published_episodes_counts = Episode.where(podcasts: @podcasts).published.group(:podcast_id).count
    @scheduled_episodes_counts = Episode.where(podcasts: @podcasts).scheduled.group(:podcast_id).count
    @drafted_episodes_counts = Episode.where(podcasts: @podcasts).draft.group(:podcast_id).count
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

    @recently_published = @podcast.episodes.published.dropdate_desc.limit(3)
    @next_scheduled = @podcast.episodes.draft_or_scheduled.dropdate_asc.limit(3)

    @metrics_jwt = prx_jwt
    @metrics_castle_root = castle_root
    @metrics_dates = 30.days.ago.utc.to_date..Time.now.utc.to_date
    @metrics_guids, @metrics_titles = published_episodes(@metrics_dates)

    @feeds = @podcast.feeds.tab_order
  end

  # GET /podcasts/new
  def new
    @podcast = Podcast.new(podcast_params)

    # TODO: get the default account from ID somehow
    @podcast.prx_account_uri = helpers.podcast_account_name_options(@podcast).first.last
    @podcast.clear_attribute_changes(%i[prx_account_uri])
  end

  # GET /podcasts/1/edit
  def edit
    @podcast.assign_attributes(podcast_params)
    authorize @podcast, :show?
  end

  # POST /podcasts
  def create
    @podcast = Podcast.new(podcast_params)
    authorize @podcast

    respond_to do |format|
      if @podcast.save
        @podcast.copy_media
        @podcast.publish!
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
        @podcast.copy_media
        @podcast.publish!
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
      if @podcast.destroy
        format.html { redirect_to podcasts_url, notice: t(".notice") }
      else
        format.html do
          flash.now[:error] = t(".error")
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:id])
  end

  def published_episodes(date_range)
    data = @podcast.episodes.published.where(published_at: date_range.first..).order(published_at: :asc).pluck(:guid, :title)
    [data.transpose[0] || [], data.transpose[1] || []]
  end

  def podcast_params
    nilify params.fetch(:podcast, {}).permit(
      :title,
      :prx_account_uri,
      :link,
      :explicit,
      :serial_order,
      :language,
      :owner_name,
      :owner_email,
      :author_name,
      :author_email,
      :managing_editor_name,
      :managing_editor_email,
      :copyright,
      :complete,
      default_feed_attributes: [
        :id,
        :subtitle,
        :description,
        :itunes_category,
        :itunes_subcategory,
        feed_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry],
        itunes_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry]
      ]
    )
  end
end
