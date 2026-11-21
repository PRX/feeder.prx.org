class LocationSearchesController < ApplicationController
  # GET /location_search
  def show
    @error = nil
    @places = nil
    @query = params[:q].to_s.squish
    if @query.length.between?(2, 200)
      @places = Nominatim.search(@query, language: params[:language])
    end
  rescue Nominatim::BusyError
    @error = :busy
  rescue Nominatim::Error
    @error = :error
  end
end
