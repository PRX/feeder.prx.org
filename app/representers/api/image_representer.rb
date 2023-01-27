class Api::ImageRepresenter < Roar::Decorator
  include Roar::JSON
  include HalApi::Representer::FormatKeys

  property :href
  property :url, writeable: false # TODO: deprecate in favor of href ... but Castle scrapes this field
  property :original_url, writeable: false
  property :alt_text
  property :caption
  property :credit
  property :format, writeable: false
  property :height, writeable: false
  property :width, writeable: false
  property :size, writeable: false
  property :status, writeable: false
end
