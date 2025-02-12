module Integrations
  module Base
    class Show
      include EpisodeSetOperations

      attr_accessor :public_feed, :private_feed

      def podcast
        private_feed.podcast
      end

      def podcast_feeder_episodes
        @podcast_feeder_episodes ||=
          podcast.episodes
            .reset
            .with_deleted
            .group_by(&:item_guid)
            .values
            .map { |eps| sort_by_episode_properties(eps) }
            .map(&:first)
      end

      # All the episodes -- including deleted and unpublished
      def podcast_episodes
        @podcast_episodes ||= podcast_feeder_episodes.map { |e| build_integration_episode(e) }
      end

      # Does not include deleted episodes
      def episodes
        @episodes ||= begin
          feed_episode_ids = Set.new(private_feed.feed_episodes.feed_ready.map(&:id))

          podcast_episodes
            .filter { |e| feed_episode_ids.include?(e.feeder_episode.id) }
        end
      end

      private

      def build_integration_episode(feeder_episode)
        raise NotImplementedError, "Subclasses must implement create_integration_episode"
      end
    end
  end
end
