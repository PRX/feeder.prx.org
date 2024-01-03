class Api::MediaResourceRepresenter < Roar::Decorator
  include Roar::JSON
  include HalApi::Representer::FormatKeys

  # TODO: uncomment once the readable href is deprecated
  # property :href, readable: false
  property :file_name
  property :mime_type, as: :type
  property :file_size, as: :size
  property :duration
  property :status, writeable: false

  # TODO: deprecate
  property :href
  property :original_url, writeable: false
end
