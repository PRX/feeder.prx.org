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
    @apple_show_options = get_apple_show_options(@feed)
  end

  # GET /feeds/new
  def new
    @feed = @podcast.feeds.new(private: false, slug: "")
    authorize @feed

    @feed.assign_attributes(feed_params)
    @feed.clear_attribute_changes(%i[file_name podcast_id private slug])
  end

  def get_apple_show_options(feed)
    if feed.apple? && feed.apple_show_id.blank? && feed.apple_config
      used_ids = used_apple_show_ids(feed)
      api = Apple::Api.from_apple_config(feed.apple_config)
      shows_json = Apple::Show.apple_shows_json(api) || []
      shows_json.map do |sj|
        if used_ids.include?(sj["id"])
          nil
        else
          ["#{sj["id"]} (#{sj["attributes"]["title"]})", sj["id"]]
        end
      end.compact
    end
  end

  def used_apple_show_ids(feed)
    Feed.apple.distinct.where("id != ?", feed.id).pluck(:apple_show_id).compact
  end

  def new_apple
    @feed = Feeds::AppleSubscription.new(podcast: @podcast, private: true)
    @feed.build_apple_config
    @feed.apple_config.build_key
    authorize @feed

    @feed.assign_attributes(feed_params)
    render "new"
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
  rescue ActiveRecord::StaleObjectError
    render :show, status: :conflict
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
    @feed.locking_enabled = true
  end

  # Only allow a list of trusted parameters through.
  def feed_params
    params.fetch(:feed, {}).permit(:slug).merge(nilified_feed_params)
  end

  def nilified_feed_params
    nilify params.fetch(:feed, {}).permit(
      :lock_version,
      :file_name,
      :title,
      :subtitle,
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
      :type,
      :apple_show_id,
      itunes_category: [],
      itunes_subcategory: [],
      feed_tokens_attributes: %i[id label token _destroy],
      feed_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry],
      itunes_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry],
      apple_config_attributes: [:id, :publish_enabled, :sync_blocks_rss, {key_attributes: %i[id provider_id key_id key_pem_b64]}]
    )
  end
end
