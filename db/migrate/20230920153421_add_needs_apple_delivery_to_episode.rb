class AddNeedsAppleDeliveryToEpisode < ActiveRecord::Migration[7.0]
  def change
    add_column :episodes, :needs_apple_delivery, :boolean, default: true

    reversible do |dir|
      dir.up do
        episode_ids = SyncLog.where(feeder_type: :episodes).pluck(:feeder_id)
        apple_episodes =
          Episode.where(id: episode_ids).map do |e|
            Apple::Episode.new(show: true, feeder_episode: e, api: true)
          end

        needs_delivery_episodes = []
        apple_episodes.each do |apple_episode|
          if (apple_episode.podcast_container.nil? || apple_episode.podcast_container.needs_delivery?) || apple_episode.apple_hosted_audio_asset_container_id.blank?
            needs_delivery_episodes << apple_episode.feeder_episode
          else
            apple_episode.feeder_episode.update!(needs_apple_delivery: false)
          end
        end

        Rails.logger.info("Needs delivery count: #{needs_delivery_episodes.length}")
        needs_delivery_episodes.sort_by(&:podcast_id).each do |ep|
          Rails.logger.info("Needs delivery episode: #{ep.id} podcast: #{ep.podcast_id}")
        end
      end
    end
  end
end
