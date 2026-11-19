# Location search via OpenStreetMap Nominatim, following its usage policy:
# https://operations.osmfoundation.org/policies/nominatim/
class Nominatim
  DEFAULT_URL = "https://nominatim.openstreetmap.org".freeze
  USER_AGENT = "PRX-Feeder-Location/1.0 (+https://prx.org; Rails-#{Rails.env})".freeze
  CACHE_EXPIRES = 1.week
  THROTTLE_KEY = "nominatim/throttle".freeze
  LIMIT = 5

  class Error < StandardError; end

  class BusyError < Error; end

  Place = Struct.new(:name, :display_name, :latitude, :longitude, :osm, :country, keyword_init: true)

  def self.search(query, language: nil)
    new.search(query, language: language)
  end

  def search(query, language: nil)
    query = query.to_s.squish
    return [] if query.blank?

    key = "nominatim/search/#{Digest::SHA256.hexdigest([language, query.downcase].join("|"))}"
    results = Rails.cache.fetch(key, expires_in: CACHE_EXPIRES) do
      throttle!
      get("search", q: query, "accept-language": language)
    end

    Array(results).map { |r| place(r) }
  end

  private

  # the public server allows at most 1 request per second, across all our servers
  def throttle!
    return if Rails.cache.write(THROTTLE_KEY, true, expires_in: 1.second, unless_exist: true)

    sleep 1
    raise BusyError, "Nominatim is busy" unless Rails.cache.write(THROTTLE_KEY, true, expires_in: 1.second, unless_exist: true)
  end

  def get(path, params)
    params = params.merge(format: "jsonv2", addressdetails: 1, limit: LIMIT, email: ENV["NOMINATIM_EMAIL"])
    connection.get(path, params.compact_blank).body
  rescue Faraday::Error => e
    Rails.logger.error("Error: GET Nominatim #{path}", error: e.message)
    raise Error, e.message
  end

  def connection
    headers = {"User-Agent" => USER_AGENT, "Accept" => "application/json"}
    Faraday.new(url: base_url, headers: headers, request: {timeout: 5, open_timeout: 5}) do |builder|
      builder.response :raise_error
      builder.response :json
      builder.response :logger, Rails.logger
    end
  end

  def base_url
    url = ENV["NOMINATIM_URL"].presence || DEFAULT_URL
    url.end_with?("/") ? url : "#{url}/"
  end

  def place(result)
    display_name = result["display_name"]
    lat, lon = result.values_at("lat", "lon")
    lat = lon = nil if lat.blank? || lon.blank?
    osm_type, osm_id = result.values_at("osm_type", "osm_id")

    name = result["name"].presence || display_name.to_s.split(",").first
    name = name.to_s.strip[0, 128]
    osm = "#{osm_type[0].upcase}#{osm_id}" if osm_type.present? && osm_id.present?
    country = result.dig("address", "country_code")&.upcase

    Place.new(name: name, display_name: display_name, latitude: lat, longitude: lon, osm: osm, country: country)
  end
end
