# encoding: utf-8
require 'hal_api/representer/collection_paging'

class Api::PagedCollectionRepresenter < Api::BaseRepresenter
  include HalApi::Representer::CollectionPaging
end
