class ImportsController < ApplicationController
  before_action :set_podcast
  before_action :set_import, only: %i[show edit update destroy]

  # GET /imports
  def index
    @imports = [] # Import.all
  end

  # GET /imports/1
  def show
  end

  # GET /imports/new
  def new
    # @import = Import.new
  end

  # GET /imports/1/edit
  def edit
  end

  # POST /imports
  def create
    # @import = Import.new(import_params)

    # respond_to do |format|
    #   if @import.save
    #     format.html { redirect_to import_url(@import), notice: "Import was successfully created." }
    #   else
    #     format.html { render :new, status: :unprocessable_entity }
    #   end
    # end
  end

  # PATCH/PUT /imports/1
  def update
    # respond_to do |format|
    #   if @import.update(import_params)
    #     format.html { redirect_to import_url(@import), notice: "Import was successfully updated." }
    #   else
    #     format.html { render :edit, status: :unprocessable_entity }
    #   end
    # end
  end

  # DELETE /imports/1
  def destroy
    # @import.destroy

    # respond_to do |format|
    #   format.html { redirect_to imports_url, notice: "Import was successfully destroyed." }
    # end
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
    params.fetch(:import, {})
  end
end
