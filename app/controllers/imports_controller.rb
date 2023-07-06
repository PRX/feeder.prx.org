class ImportsController < ApplicationController
  before_action :set_podcast
  # before_action :set_import, only: %i[show]

  # GET /imports
  def index
    @imports = PodcastImport.where(podcast_id: @podcast).order(created_at: :desc)
    @import = PodcastImport.new(account_id: @podcast.account_id, podcast_id: @podcast.id)
    authorize @import
  end

  # POST /imports
  def create
    # validate RSS
    # validate URL
    @import = PodcastImport.new(import_params)
    authorize @import

    respond_to do |format|
      if @import.save
        @import.import_later
        format.html { redirect_to podcast_imports_path(@podcast), notice: "Beginning import." }
      else
        format.html do
          flash.now[:notice] = "Could not begin import."
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_import
    # @import = Import.find(params[:id])
  end

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  # Only allow a list of trusted parameters through.
  def import_params
    params.fetch(:podcast_import, {}).permit(
      :account_id,
      :podcast_id,
      :url
    )
  end
end
