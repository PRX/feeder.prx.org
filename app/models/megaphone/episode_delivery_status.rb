module Megaphone
  class EpisodeDeliveryStatus < Integrations::EpisodeDeliveryStatus
    def self.sti_name
      "megaphone"
    end

    def self.current(episode)
      where(episode_id: episode.id).order(created_at: :desc).first
    end

    def self.current_or_default(episode)
      current(episode) || default_status(episode)
    end

    def self.default_status(episode)
      new(episode: episode)
    end

    def self.update_status(episode, attrs)
      new_status = current(episode)&.dup || default_status(episode)
      new_status.assign_attributes(attrs)
      new_status.save!
      episode.episode_delivery_statuses.reset
      new_status
    end

    def self.delete_status(episode)
      episode.episode_delivery_statuses.megaphone.delete_all
    end

    def self.unfinished(episodes)
      integration = integrations.fetch("megaphone")
      latest_status = <<~SQL
        left join lateral (
          select "integrations_episode_delivery_statuses".*
          from "integrations_episode_delivery_statuses"
          where "episodes"."id" = "integrations_episode_delivery_statuses"."episode_id"
            and "integrations_episode_delivery_statuses"."integration" = #{integration}
          order by "integrations_episode_delivery_statuses"."created_at" desc
          limit 1
        ) eds on true
      SQL

      episodes
        .joins(latest_status)
        .where('(eds."episode_id" is null) or ((eds."delivered" = false or eds."uploaded" = false) and eds."integration" = ?)', integration)
    end

    def mark_as_uploaded!
      update_status(uploaded: true)
    end

    def mark_as_not_uploaded!
      update_status(uploaded: false)
    end

    # Whether the media file has been uploaded to Megaphone is a subset of
    # whether the episode has been delivered.
    def mark_as_delivered!
      update_status(delivered: true, uploaded: true, asset_processing_attempts: 0)
    end

    def mark_as_not_delivered!
      # source_media_version_id is intentionally omitted — it is preserved so
      # we can still compare the previously uploaded media version against the
      # current one.
      update_status(delivered: false, uploaded: false, asset_processing_attempts: 0)
    end

    private

    def update_status(attrs)
      self.class.update_status(episode, attrs)
    end
  end
end
