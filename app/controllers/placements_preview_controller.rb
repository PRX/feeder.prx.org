class PlacementsPreviewController < ApplicationController
  include PrxAccess

  before_action :set_podcast

  # GET /podcasts/1/placements_preview/2
  def show
    @fetch_error = cached_placements.nil?
    @zones = get_zones(params[:id].to_i)
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  end

  def placements_href
    "/api/v1/podcasts/#{@podcast.id}/placements"
  end

  def fetch_placements
    api(root: augury_root, account: "*").tap { |a| a.href = placements_href }.get
  rescue HyperResource::ClientError, HyperResource::ServerError
    nil
  end

  def cached_placements
    Rails.cache.fetch(placements_href, expires_in: 1.minute) do
      fetch_placements
    end
  end

  def get_placement(original_count)
    cached_placements&.find { |i| i.original_count == original_count }
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
