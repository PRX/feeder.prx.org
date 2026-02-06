class PodcastStreamController < ApplicationController
  before_action :set_stream

  def show
  end

  def update
    @stream.assign_attributes(stream_params)

    respond_to do |format|
      if @stream.save
        format.html { redirect_to podcast_stream_path(@podcast), notice: t(".notice") }
      else
        flash.now[:error] = t(".error")
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::StaleObjectError
    render :show, status: :conflict
  end

  private

  def set_stream
    @podcast = Podcast.find(params[:podcast_id])
    @stream = @podcast.stream_recording || @podcast.build_stream_recording
    @stream.clear_attribute_changes(%i[podcast_id])
    @stream.locking_enabled = true
    authorize @stream
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  def stream_params
    nilify params.fetch(:stream_recording, {}).permit(
      :lock_version,
      :url,
      :status,
      :start_date,
      :end_date,
      :create_as,
      :expiration,
      :time_zone,
      record_days: [],
      record_hours: []
    )
  end
end
