class FeedsController < ApplicationController
  before_action :set_feed, only: %i[show edit update destroy]
  before_action :set_podcast

  # GET /feeds
  def index
    @feeds = Feed.all.limit(10)
  end

  # GET /feeds/1
  def show
  end

  # GET /feeds/new
  def new
    @feed = Feed.new
  end

  # GET /feeds/1/edit
  def edit
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
    respond_to do |format|
      if @feed.update(feed_params)
        format.html { redirect_to feed_url(@feed), notice: "Feed was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
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
    params.fetch(:feed, {})
  end
end
