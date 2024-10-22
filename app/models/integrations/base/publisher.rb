module Integrations
  module Base
    class Publisher
      include EpisodeSetOperations

      attr_reader :show

      def initialize(show:)
        @show = show
      end

      def episodes_to_sync
        filter_episodes_to_sync(show.episodes)
      end

      def episodes_to_archive
        filter_episodes_to_archive(show.podcast_episodes, Set.new(show.episodes))
      end

      def episodes_to_unarchive
        filter_episodes_to_unarchive(show.episodes)
      end

      def publish!
        raise NotImplementedError, "Subclasses must implement publish!"
      end
    end
  end
end
