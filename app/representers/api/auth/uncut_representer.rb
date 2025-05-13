class Api::Auth::UncutRepresenter < Api::UncutRepresenter
  property :href
  property :original_url, writeable: false
end
