class AddNeedsAppleDeliveryToEpisode < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_episode_delivery_statuses do |t|
      t.references :episode, null: false, foreign_key: true
      t.boolean :delivered, default: false

      t.datetime :created_at, null: false
    end

    execute('CREATE INDEX "index_apple_episode_delivery_statuses_on_episode_id_created_at" ON "apple_episode_delivery_statuses" ("episode_id", "created_at") INCLUDE (delivered);')

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
            apple_episode.feeder_episode.apple_needs_delivery!
            needs_delivery_episodes << apple_episode.feeder_episode
          else
            apple_episode.feeder_episode.apple_has_delivery!
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
