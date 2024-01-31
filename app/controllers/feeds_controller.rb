class FeedsController < ApplicationController
  before_action :set_feed, only: %i[show update destroy]
  before_action :set_podcast
  before_action :set_feeds

  def index
    redirect_to podcast_feed_url(@podcast, @podcast.default_feed)
  end

  # GET /feeds/1
  def show
    @feed.assign_attributes(feed_params)
    authorize @feed
  end

  # GET /feeds/new
  def new
    @feed = @podcast.feeds.new(private: false, slug: "")
    authorize @feed

    @feed.assign_attributes(feed_params)
    @feed.clear_attribute_changes(%i[file_name podcast_id private slug])
  end

  # POST /feeds
  def create
    @feed = @podcast.feeds.new(feed_params)
    @feed.slug = "" if @feed.slug.nil?
    authorize @feed

    respond_to do |format|
      if @feed.save
        @feed.copy_media
        @feed.podcast&.publish!
        format.html { redirect_to podcast_feed_path(@podcast, @feed), notice: t(".success", model: "Feed") }
      else
        format.html do
          flash.now[:error] = t(".failure", model: "Feed")
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH/PUT /feeds/1
  def update
    @feed.assign_attributes(feed_params)
    authorize @feed

    respond_to do |format|
      if @feed.save
        @feed.copy_media
        @feed.podcast&.publish!
        format.html { redirect_to podcast_feed_path(@podcast, @feed), notice: t(".success", model: "Feed") }
      else
        format.html do
          flash.now[:error] = t(".failure", model: "Feed")
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /feeds/1
  def destroy
    respond_to do |format|
      if @feed.destroy
        @feed.podcast&.publish!
        format.html { redirect_to podcast_feed_path(@podcast, @podcast.default_feed), notice: t(".success", model: "Feed") }
      else
        format.html do
          flash.now[:notice] = t(".failure", model: "Feed")
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_podcast
    @podcast =
      if @feed
        @feed.podcast
      elsif params[:podcast_id].present?
        Podcast.find(params[:podcast_id])
      end
  end

  def set_feeds
    @feeds = @podcast.feeds.tab_order
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_feed
    @feed = Feed.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def feed_params
    params.fetch(:feed, {}).permit(:slug).merge(nilified_feed_params)
  end

  def nilified_feed_params
    nilify params.fetch(:feed, {}).permit(
      :file_name,
      :title,
      :subtitle,
      :summary,
      :description,
      :include_donation_url,
      :include_podcast_value,
      :private,
      :url,
      :new_feed_url,
      :enclosure_prefix,
      :display_episodes_count,
      :display_full_episodes_count,
      :episode_offset_seconds,
      :audio_type,
      :audio_bitrate,
      :audio_bitdepth,
      :audio_channel,
      :audio_sample,
      :billboard,
      :house,
      :paid,
      :sonic_id,
      include_tags: [],
      itunes_category: [],
      itunes_subcategory: [],
      feed_tokens_attributes: %i[id label token _destroy],
      feed_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry],
      itunes_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry]
    )
  end
end
