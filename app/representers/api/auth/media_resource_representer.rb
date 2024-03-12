class Api::Auth::MediaResourceRepresenter < Api::MediaResourceRepresenter
  property :href
  property :original_url, writeable: false
end
