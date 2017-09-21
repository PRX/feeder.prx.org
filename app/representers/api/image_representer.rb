# encoding: utf-8

class Api::ImageRepresenter < Roar::Decorator
  include Roar::JSON

  property :url
  property :original_url, writeable: false
  property :link
  property :description
  property :format
  property :height
  property :width
  property :size
end
