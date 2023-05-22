module Feedjira
  module Parser
    class PodcastImage
      include SAXMachine

      # required
      element :url
      element :title
      element :link

      # optional
      element :width
      element :height
      element :description
    end
  end
end
