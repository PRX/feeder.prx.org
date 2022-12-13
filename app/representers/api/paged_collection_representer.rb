require 'api/base_representer'
require 'hal_api/representer/collection_paging'

class Api::PagedCollectionRepresenter < Api::BaseRepresenter
  include HalApi::Representer::CollectionPaging
end
