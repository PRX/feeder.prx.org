class FeedsController < ApplicationController
  before_action :set_feed, only: %i[show update destroy]
  before_action :set_podcast
  before_action :set_feeds

  def index
    redirect_to podcast_feed_url(@podcast, @podcast.default_feed)
  end

  # GET /feeds/1
  def show
    init_config
    authorize @feed
    @apple_show_options = get_apple_show_options(@feed)
    load_apple_connection_options
  end

  # GET /feeds/new
  def new
    @feed = @podcast.feeds.new(private: false, slug: "")
    authorize @feed

    @feed.assign_attributes(feed_params)
    @feed.clear_attribute_changes(%i[file_name podcast_id private slug])
  end

  def get_apple_show_options(feed)
    if feed.integration_type == :apple && feed.delegated_delivery_config&.key
      feed.apple_show_options
    else
      []
    end
  end

  def new_apple
    @feed = Feeds::AppleSubscription.new(podcast: @podcast, private: true)
    authorize @feed
    init_config
    render "new"
  end

  def new_megaphone
    @feed = Feeds::MegaphoneFeed.new(podcast: @podcast, private: true)
    authorize @feed
    init_config
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
      if save_feed_and_apple_connection
        @feed.copy_media
        @feed.podcast&.publish!
        format.html { redirect_to podcast_feed_path(@podcast, @feed), notice: t(".success", model: "Feed") }
      else
        format.html do
          flash.now[:error] = t(".failure", model: "Feed")
          load_apple_connection_options
          render :show, status: :unprocessable_entity
        end
      end
    end
  rescue ActiveRecord::StaleObjectError
    load_apple_connection_options
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

  def init_config
    @feed.assign_attributes(feed_params)
    if @feed.is_a? Feeds::AppleSubscription
      @feed.build_delegated_delivery_config unless @feed.delegated_delivery_config
      @feed.delegated_delivery_config.build_key unless @feed.delegated_delivery_config.key
      @feed.delegated_delivery_config.key.account_id ||= @podcast.account_id
    elsif @feed.is_a? Feeds::MegaphoneFeed
      @feed.megaphone_config || @feed.build_megaphone_config
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
      delegated_delivery_config_attributes: [:id, :publish_enabled, :sync_blocks_rss, {key_attributes: %i[id provider_id key_id key_pem_b64]}],
      megaphone_config_attributes: [:id, :publish_enabled, :sync_blocks_rss, :token, :network_id, :network_name, :organization_id, advertising_tags: []]
    )
  end

  def exclude_default_episodes?
    params[:feed][:exclude_default_episodes] == "1"
  end

  def load_apple_connection_options
    @apple_connection_options = []
    return unless @feed.persisted? && @feed.public?

    keys = policy_scope(Apple::Key).for_account(@podcast.account_id).order(:created_at)
    options = Apple::ShowFeedBinding.connection_options(keys)

    if (binding = @feed.apple_show_feed_binding) && options.none? { |option| option.value == binding.connection_token }
      label = "#{binding.apple_show_id} · Key …#{binding.feed.podcast.apple_key.key_id.to_s.last(4)}"
      options.prepend(Apple::ShowFeedBinding::ConnectionOption.new(label, binding.connection_token))
    end

    @apple_connection_options = options.map { |option| [option.label, option.value] }
  end

  def save_feed_and_apple_connection
    saved = false

    Feed.transaction do
      if @feed.save && save_apple_connection
        saved = true
      else
        raise ActiveRecord::Rollback
      end
    end

    saved
  end

  def save_apple_connection
    return true unless @feed.persisted? && @feed.public?

    current_binding = @feed.apple_show_feed_binding
    selection = @feed.apple_connection
    return true if selection == current_binding&.connection_token

    if selection.blank?
      return disconnect_apple_binding(current_binding)
    end

    parsed = Apple::ShowFeedBinding.parse_connection_token(selection)
    return apple_connection_error("is invalid") unless parsed

    apple_key_id, apple_show_id = parsed
    apple_key = policy_scope(Apple::Key).for_account(@podcast.account_id).find_by(id: apple_key_id)
    return apple_connection_error("uses an unavailable credential") unless apple_key

    binding = Apple::ShowFeedBinding.connect_existing(
      feed: @feed,
      apple_key: apple_key,
      apple_show_id: apple_show_id
    )

    if binding.persisted? && binding.errors.empty?
      mirror_legacy_apple_routing(binding) if @feed.default?
      true
    else
      binding.errors.full_messages.each { |message| @feed.errors.add(:apple_connection, message) }
      false
    end
  end

  def disconnect_apple_binding(binding)
    return true unless binding

    if binding.delegated_delivery_config
      apple_connection_error("cannot be removed while delegated-delivery feeds use it")
    else
      binding.destroy!
      true
    end
  end

  def mirror_legacy_apple_routing(binding)
    config = binding.delegated_delivery_config
    return unless config

    config.update!(key: binding.feed.podcast.apple_key)
    config.private_feed.update!(apple_show_id: binding.apple_show_id)
  end

  def apple_connection_error(message)
    @feed.errors.add(:apple_connection, message)
    false
  end
end
