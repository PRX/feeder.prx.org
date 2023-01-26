class Api::ITunesCategoryRepresenter < Roar::Decorator
  include Roar::JSON

  property :name
  property :subcategories
end
