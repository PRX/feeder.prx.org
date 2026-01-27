class PodcastStreamHoursController < ApplicationController
  before_action :set_stream

  def index
    @end_date = params[:end_date]&.to_date || (Date.utc_today.beginning_of_month + 1.month)
    @start_date = @end_date - 3.months
    @range = @start_date...@end_date
    @months = @range.select { |d| d.day == 1 }
    @resource_counts = @stream.stream_resources.where(start_at: @range).group("start_at::DATE").count
  end

  def show
    @date = params[:id].to_date
    @range = @date...(@date + 1.day)
    @resources = @stream.stream_resources.where(start_at: @range).order(start_at: :asc)
  end

  private

  def set_stream
    @podcast = Podcast.find(params[:podcast_id])
    @stream = @podcast.stream_recording
    raise ActiveRecord::RecordNotFound unless @stream
    authorize @stream, :show?
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end
end
