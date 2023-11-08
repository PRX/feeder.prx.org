class Api::MediaResourceRepresenter < Roar::Decorator
  include Roar::JSON
  include HalApi::Representer::FormatKeys

  property :file_name
  property :mime_type, as: :type
  property :file_size, as: :size
  property :duration
  property :status, writeable: false
end
