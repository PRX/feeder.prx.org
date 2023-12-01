class EpisodesController < ApplicationController
  before_action :set_episode, only: %i[show edit update destroy]
  before_action :set_podcast

  # GET /episodes
  def index
    if params[:sort].present?
      @episodes =
        episodes_query
          .paginate(params[:page], params[:per])
    else
      @published_episodes =
        episodes_query
          .published
          .dropdate_desc
          .paginate(params[:published_page], params[:per])
      @scheduled_episodes =
        episodes_query
          .draft_or_scheduled
          .dropdate_asc
          .paginate(params[:scheduled_page], params[:per])
    end
  end

  # GET /episodes/1
  def show
    redirect_to edit_episode_url(@episode)
  end

  # GET /episodes/new
  def new
    @episode = Episode.new(episode_params)
    @episode.podcast = @podcast
    @episode.clear_attribute_changes(%i[podcast_id])
    @episode.strict_validations = true
    @episode.valid? if turbo_frame_request?
    authorize @episode, :create?
  end

  # GET /episodes/1/edit
  def edit
    @episode.assign_attributes(episode_params)
    authorize @episode, :show?
    @episode.valid?
  end

  # POST /podcasts/1/episodes
  def create
    @episode = Episode.new(episode_params)
    @episode.podcast = @podcast
    @episode.strict_validations = true
    authorize @episode

    respond_to do |format|
      if @episode.save
        @episode.copy_media
        @episode.publish!
        format.html { redirect_to edit_episode_url(@episode), notice: t(".notice") }
      elsif @episode.errors.added?(:base, :media_not_ready)
        flash.now[:error] = t(".media_not_ready")
        format.html { render :edit, status: :unprocessable_entity }
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
        @episode.copy_media
        @episode.publish!
        format.html { redirect_to edit_episode_url(@episode), notice: t(".notice") }
      elsif @episode.errors.added?(:base, :media_not_ready)
        flash.now[:error] = t(".media_not_ready")
        format.html { render :edit, status: :unprocessable_entity }
      else
        flash.now[:error] = t(".error")
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /episodes/1
  def destroy
    authorize @episode

    respond_to do |format|
      if @episode.destroy
        @episode.publish!
        format.html { redirect_to podcast_episodes_url(@episode.podcast_id), notice: t(".notice") }
      else
        format.html do
          flash.now[:error] = t(".error")
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_episode
    @episode = Episode.find_by_guid!(params[:id])
    @episode.strict_validations = true
  end

  def set_podcast
    if @episode
      @podcast = @episode.podcast
    elsif params[:podcast_id].present?
      @podcast = Podcast.find(params[:podcast_id])
      authorize @podcast, :show?
    end
  end

  def episodes_base
    if @podcast
      policy_scope(@podcast.episodes).reorder(nil)
    else
      policy_scope(Episode).all
    end
  end

  def episodes_query
    episodes_base
      .filter_by_title(params[:q])
      .filter_by_alias(params[:filter])
      .sort_by_alias(params[:sort])
  end

  def episode_params
    nilify(params.fetch(:episode, {}).permit(
      :title,
      :clean_title,
      :subtitle,
      :description,
      :production_notes,
      :explicit_option,
      :itunes_type,
      :season_number,
      :episode_number,
      :author_name,
      :author_email,
      :released_at,
      :publishing_status,
      :url,
      :item_guid,
      :original_guid,
      categories: [],
      images_attributes: %i[id original_url size alt_text caption credit _destroy _retry]
    ).tap do |p|
      p[:released_at] = released_at_zone.parse(p[:released_at]) if p[:released_at].present?
    end)
  end

  # released_at needs to be parsed in the selected zone
  def released_at_zone
    zone_name = params.fetch(:episode, {}).fetch(:released_at_zone, "")
    ActiveSupport::TimeZone[zone_name] || ActiveSupport::TimeZone["UTC"]
  end
end
