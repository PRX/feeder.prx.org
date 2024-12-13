class PlacementsPreviewController < ApplicationController
  include Prx::Api

  before_action :set_podcast

  # GET /podcasts/1/placements_preview/2
  def show
    @zones = get_zones(params[:id].to_i)
    @fetch_error = @zones.nil?
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  end

  def get_placement(original_count)
    placements = Prx::Augury.new.placements(@podcast.id)
    placements&.find { |i| i.original_count == original_count }
  end

  def get_zones(original_count)
    if (p = get_placement(original_count))
      p.zones.map(&:with_indifferent_access)
    else
      original_count.times.map do |n|
        {
          id: "original_#{n + 1}",
          name: "Original #{n + 1}",
          type: "original",
          section: "original"
        }.with_indifferent_access
      end
    end
  end
end
