# encoding: utf-8

class Api::MediaResourceRepresenter < Roar::Decorator
  include Roar::JSON

  property :url, as: :href
  property :mime_type, as: :type
  property :file_size, as: :size
  property :duration
  property :status
end
