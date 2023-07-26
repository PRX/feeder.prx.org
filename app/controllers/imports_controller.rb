class ImportsController < ApplicationController
  before_action :set_podcast
  before_action :set_import, only: :show

  # GET /imports
  def index
    @imports = @podcast.podcast_imports
    @import = @podcast.podcast_imports.new
    authorize @podcast, :show?
  end

  def show
    authorize @podcast, :show?
  end

  # POST /imports
  def create
    @imports = @podcast.podcast_imports
    @import = @podcast.podcast_imports.new(import_params)
    authorize @import
    begin
      @import.get_feed
    rescue URI::InvalidURIError
      flash.now[:notice] = t(".failure_get_feed")
      render :index, status: :unprocessable_entity
      return
    end

    respond_to do |format|
      if @import.save
        @import.import_later
        format.html { redirect_to podcast_import_path(@podcast, @import), notice: t(".success") }
      else
        format.html do
          flash.now[:notice] = t(".failure")
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_import
    @import = PodcastImport.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def import_params
    params.fetch(:podcast_import, {}).permit(
      :url
    )
  end
end
