# encoding: utf-8

class Api::MediaResourceRepresenter < Roar::Decorator
  include Roar::JSON

  property :href
  property :mime_type, as: :type
  property :file_size, as: :size
  property :duration
  property :status, writeable: false
end
