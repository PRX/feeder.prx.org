module Feedjira
  module Parser
    class MediaGroup
      include SAXMachine

      elements :"media:content", as: :media_contents, class: MediaContent
    end
  end
end
