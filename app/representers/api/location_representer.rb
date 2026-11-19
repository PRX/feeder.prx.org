class Api::LocationRepresenter < Roar::Decorator
  include Roar::JSON

  property :name
  property :rel
  property :latitude, getter: ->(*) { latitude&.to_f }
  property :longitude, getter: ->(*) { longitude&.to_f }
  property :osm
  property :country
end
