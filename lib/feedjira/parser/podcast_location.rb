module Feedjira
  module Parser
    class PodcastLocation
      include SAXMachine

      value :name
      attribute :rel
      attribute :geo
      attribute :osm
      attribute :country
    end
  end
end
