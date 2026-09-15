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
    prepare_feed_form
  end

  # GET /feeds/new
  def new
    @feed = @podcast.feeds.new(private: false, slug: "")
    authorize @feed

    @feed.assign_attributes(feed_params)
    @feed.clear_attribute_changes(%i[file_name podcast_id private slug])
  end

  def new_megaphone
    @feed = Feeds::MegaphoneFeed.new(podcast: @podcast, private: true)
    authorize @feed
    @feed.assign_attributes(feed_params)
    prepare_feed_form
    render "new"
  end

  # POST /feeds
  def create
    @feed = @podcast.feeds.new(feed_params)
    @feed.slug = "" if @feed.slug.nil?
    authorize @feed

    respond_to do |format|
      if @feed.save
        @feed.set_default_episodes unless exclude_default_episodes?
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
      if @feed.save_with_apple_connection
        @feed.copy_media
        @feed.podcast&.publish!
        format.html { redirect_to podcast_feed_path(@podcast, @feed), notice: t(".success", model: "Feed") }
      else
        format.html do
          flash.now[:error] = t(".failure", model: "Feed")
          prepare_feed_form
          render :show, status: :unprocessable_entity
        end
      end
    end
  rescue ActiveRecord::StaleObjectError
    prepare_feed_form
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
          flash.now[:error] = @feed.errors.full_messages.to_sentence
          prepare_feed_form
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def prepare_feed_form
    if @feed.is_a? Feeds::MegaphoneFeed
      @feed.megaphone_config || @feed.build_megaphone_config
    elsif @feed.persisted?
      @delegated_delivery_config = @feed.delegated_delivery_config || Apple::DelegatedDeliveryConfig.new
      @apple_delivery_bindings = Apple::ShowFeedBinding.available_for_delivery(@feed)
      load_apple_connection_options
    end
  end

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
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  # Only allow a list of trusted parameters through.
  def feed_params
    params.fetch(:feed, {}).permit(:slug).merge(nilified_feed_params)
  end

  def nilified_feed_params
    nilify params.fetch(:feed, {}).permit(
      :lock_version,
      :file_name,
      :label,
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
      :episode_footer,
      :unique_guids,
      :import_locked,
      :apple_verify_token,
      :apple_connection,
      itunes_category: [],
      itunes_subcategory: [],
      feed_tokens_attributes: %i[id label token _destroy],
      feed_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry],
      itunes_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry],
      delegated_delivery_config_attributes: %i[id show_feed_binding_id publish_enabled sync_blocks_rss _destroy],
      megaphone_config_attributes: [:id, :publish_enabled, :sync_blocks_rss, :token, :network_id, :network_name, :organization_id, advertising_tags: []]
    )
  end

  def exclude_default_episodes?
    params[:feed][:exclude_default_episodes] == "1"
  end

  def load_apple_connection_options
    @apple_connection_options = []
    return unless @feed.persisted? && @feed.public?

    options = Apple::ShowFeedBinding.connection_options(@podcast.apple_key) do
      @apple_show_lookup_failed = true
    end

    if (binding = @feed.apple_show_feed_binding) && options.none? { |option| option.value == binding.apple_show_id.to_s }
      options.prepend(Apple::ShowFeedBinding::ConnectionOption.new(binding.apple_show_id.to_s, binding.apple_show_id.to_s))
    end

    @apple_connection_options = options.map { |option| [option.label, option.value] }
  end
end
