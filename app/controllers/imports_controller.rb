class ImportsController < ApplicationController
  before_action :set_podcast
  before_action :set_import, only: :show

  # GET /imports
  def index
    @imports = @podcast.podcast_imports
    @import = @podcast.podcast_imports.new
    authorize @import
  end

  def show
  end

  # POST /imports
  def create
    @import = @podcast.podcast_imports.new(import_params)
    authorize @import
    @import.get_feed

    respond_to do |format|
      if @import.save
        @import.import_later
        format.html { redirect_to podcast_imports_path(@podcast), notice: "Beginning import." }
      else
        format.html do
          flash.now[:notice] = "Could not begin import."
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
