module Feedjira
  module Parser
    class MediaContent
      include SAXMachine

      attribute :url
      attribute :fileSize, as: :file_size
      attribute :type
      attribute :medium
      attribute :isDefault, as: :is_default
      attribute :expression
      attribute :bitrate
      attribute :framerate
      attribute :samplingrate
      attribute :channels
      attribute :duration
      attribute :height
      attribute :width
      attribute :lang
    end
  end
end
