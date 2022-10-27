# encoding: utf-8

class Api::ImageRepresenter < Roar::Decorator
  include Roar::JSON
  include HalApi::Representer::FormatKeys

  property :href
  property :url, writeable: false # TODO: deprecate in favor of href ... but Castle scrapes this field
  property :original_url, writeable: false
  property :link
  property :description
  property :format, writeable: false
  property :height, writeable: false
  property :width, writeable: false
  property :size, writeable: false
  property :status, writeable: false
end
