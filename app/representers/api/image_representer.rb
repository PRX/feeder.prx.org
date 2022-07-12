# encoding: utf-8

class Api::ImageRepresenter < Roar::Decorator
  include Roar::JSON
  include HalApi::Representer::FormatKeys

  property :url, writeable: false
  property :original_url
  property :link
  property :description
  property :format, writeable: false
  property :height, writeable: false
  property :width, writeable: false
  property :size, writeable: false
  property :status, writeable: false
end
