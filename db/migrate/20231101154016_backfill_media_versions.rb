class BackfillMediaVersions < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        episodes = Episode.where(id: Integrations::EpisodeDeliveryStatus.distinct.pluck(:episode_id))

        episodes.each do |episode|
          ds = episode.apple_episode_delivery_status
          # If we have a delivered episode with all the source metadata, we can backfill the media version
          # Otherise, it needs delivery again or it needs metadata again. Either way, we can ignore it
          if ds.present? &&
              ds.delivered?
            episode.apple_update_delivery_status(source_media_version_id: episode.media_version_id)
          end
        end
      end
    end
  end
end
