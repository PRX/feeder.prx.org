module Integrations
  module Base
    module EpisodeSetOperations
      # In the case where there are duplicate guids in the feeds, we want to make
      # sure that the most "current" episode is the one that maps to the remote state.
      def sort_by_episode_properties(eps)
        # Sort the episodes by:
        # 1. Non-deleted episodes first
        # 2. Published episodes first
        # 3. Published date most recent first
        # 4. Created date most recent first
        eps =
          eps.sort_by do |e|
            [
              e.deleted_at.nil? ? 1 : -1,
              e.published_at.present? ? 1 : -1,
              e.published_at || e.created_at,
              e.created_at
            ]
          end

        # return sorted list, reversed
        # modeling a priority queue -- most important first
        eps.reverse
      end

      def filter_episodes_to_sync(eps)
        # Reject episodes if the audio is marked as uploaded/complete
        # or if the episode is a video
        eps
          .reject(&:synced_with_integration?)
          .reject(&:video_content_type?)
      end

      def filter_episodes_to_archive(eps, eps_in_feed)
        # Episodes to archive can include:
        # - episodes that are now excluded from the feed
        # - episodes that are deleted or unpublished
        # - episodes that have fallen off the end of the feed (Feed#display_episodes_count)
        eps
          .reject { |ep| eps_in_feed.include?(ep) }
          .reject(&:integration_new?)
          .reject(&:archived?)
      end

      def filter_episodes_to_unarchive(eps)
        eps.filter(&:archived?)
      end

      # Only select episodes that have an remote integration state
      def only_episodes_with_integration_state(eps)
        eps.reject(&:integration_new?)
      end
    end
  end
end
