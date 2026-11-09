require "api/paged_collection_representer"
HalApi::PagedCollection.representer_class = Api::PagedCollectionRepresenter

# allow second enclosure link for video
HalApi::Representer::Curies::ClassMethods::LINK_RELATIONS << "alternate_enclosure"
HalApi::Representer::Curies::ClassMethods::LINK_RELATIONS << "alternate-enclosure"
