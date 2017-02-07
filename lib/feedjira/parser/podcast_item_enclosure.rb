module Feedjira
  module Parser
    class PodcastItemEnclosure
      include SAXMachine

      attribute :url
      attribute :length
      attribute :type

      def to_s
        "\#<PodcastItemEnclosure url: \"#{url}\", length: \"#{length}\", type: \"#{type}\">"
      end
    end
  end
end
