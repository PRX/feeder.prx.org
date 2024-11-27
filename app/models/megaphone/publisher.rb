module Megaphone
  class Publisher < Integrations::Base::Publisher
    def initialize(feed)
      @feed = feed
    end

    def publish!
      # megaphone_podcast = Megaphone::Podcast.find_or_create!(feed)
    end
  end
end
