class FeedsController < ApplicationController
  before_action :set_feed, only: %i[show update destroy]
  before_action :set_podcast

  # GET /feeds/1
  def show
    @feed.assign_attributes(feed_params)
    authorize @feed

    @custom_feeds = @podcast.feeds.custom.order(created_at: :asc)
  end

  # GET /feeds/new
  def new
    @feed = Feed.new
  end

  # POST /feeds
  def create
    @feed = Feed.new(feed_params)

    respond_to do |format|
      if @feed.save
        format.html { redirect_to feed_url(@feed), notice: "Feed was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
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
        format.html { redirect_to podcast_feed_path(@podcast, @feed), notice: (t ".success", model: "Feed") }
      else
        format.html do
          flash.alert = t ".failure", model: "Feed"
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /feeds/1
  def destroy
    @feed.destroy

    respond_to do |format|
      format.html { redirect_to feeds_url, notice: "Feed was successfully destroyed." }
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

  # Use callbacks to share common setup or constraints between actions.
  def set_feed
    @feed = Feed.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def feed_params
    params.fetch(:feed, {}).permit(
      :file_name,
      :slug,
      :title,
      :subtitle,
      :description,
      :summary,
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
      feed_tokens_attributes: %i[id label token _destroy],
      feed_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry],
      itunes_images_attributes: %i[id original_url size alt_text caption credit _destroy _retry]
    )
  end
end
