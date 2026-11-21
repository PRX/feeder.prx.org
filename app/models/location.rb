class Location < ApplicationRecord
  # recommended formats for geo and osm are based on the Podcast Namespace Location spec and RFC 5870
  # https://github.com/Podcastindex-org/podcast-namespace/blob/main/docs/examples/location/location.md#geo-recommended
  # https://datatracker.ietf.org/doc/html/rfc5870
  GEO_FORMAT = /\Ageo:(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)(?:,-?\d+(?:\.\d+)?)?(?:;[\w.\-]+=[\w.\-]+)*\z/
  OSM_FORMAT = /\A[NWR]\d+(#\d+)?\z/
  OSM_TYPES = {"N" => "node", "W" => "way", "R" => "relation"}.freeze
  OSM_DEFAULT_URL = "https://www.openstreetmap.org".freeze

  enum :rel, %w[subject creator].to_enum_h, prefix: true
  belongs_to :owner, -> { with_deleted }, polymorphic: true, optional: true, touch: true

  normalizes :country, with: ->(c) { c.strip.upcase }

  validates :name, presence: true, length: {maximum: 128}
  validates :rel, presence: true
  validates :latitude, numericality: {in: -90..90}, allow_nil: true
  validates :longitude, numericality: {in: -180..180}, allow_nil: true
  validates :latitude, presence: true, if: :longitude
  validates :longitude, presence: true, if: :latitude
  validates :osm, format: OSM_FORMAT, allow_blank: true
  validates :country, format: /\A[A-Z]{2}\z/, allow_blank: true

  def geo
    "geo:#{latitude},#{longitude}" if latitude && longitude
  end

  # parse lat/lon from a geo uri, ignoring altitude and params
  def geo=(uri)
    self.latitude, self.longitude = uri.to_s.strip.match(GEO_FORMAT)&.captures
  end

  def self.osm_url(path = nil)
    base = (ENV["OSM_URL"].presence || OSM_DEFAULT_URL).chomp("/")
    path.present? ? "#{base}/#{path}" : base
  end

  def osm_url
    if osm.present? && osm.match?(OSM_FORMAT)
      type, id = osm[0], osm[1..].split("#").first
      self.class.osm_url("#{OSM_TYPES[type]}/#{id}")
    end
  end
end
