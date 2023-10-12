class ImportsController < ApplicationController
  before_action :set_podcast
  before_action :set_import, only: :show

  # GET /imports
  def index
    @imports = @podcast.podcast_imports.order(created_at: :asc)
    @import = @podcast.podcast_imports.new(import_params)
    @import.clear_attribute_changes(%i[type])

    authorize @podcast, :show?
  end

  def show
    authorize @podcast, :show?
  end

  # POST /imports
  def create
    @imports = @podcast.podcast_imports.order(created_at: :asc)
    @import = @podcast.podcast_imports.new(import_params)
    @import.clear_attribute_changes(%i[type])
    authorize @import

    respond_to do |format|
      if @import.save
        @import.import_later
        format.html { redirect_to podcast_import_path(@podcast, @import), notice: t(".success") }
      else
        format.html do
          flash.now[:error] = t(".failure")
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
      :import_metadata,
      :timings,
      :type,
      :url
    ).reverse_merge(type: "PodcastRssImport")
  end
end
