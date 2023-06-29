class ImportsController < ApplicationController
  before_action :set_podcast
  # before_action :set_import, only: %i[show]

  # GET /imports/1
  def show
  end

  # GET /imports/new
  def new
    @import = PodcastImport.new(account_id: @podcast.account_id, podcast_id: @podcast.id)
    authorize @import
  end

  # POST /imports
  def create
    # validate RSS
    # validate URL
    # create podcast import instance
    import = PodcastImport.new(import_params)
    # import later
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
