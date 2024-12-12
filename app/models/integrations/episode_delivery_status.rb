module Integrations
  class EpisodeDeliveryStatus < ApplicationRecord
    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"

    enum :integration, Integrations::INTEGRATIONS

    def self.update_status(integration, episode, attrs)
      new_status = (episode.episode_delivery_status(integration)&.dup || default_status(integration, episode))
      attrs[:integration] = integration
      new_status.assign_attributes(attrs)
      new_status.save!
      episode.episode_delivery_statuses.reset
      new_status
    end

    def self.default_status(integration, episode)
      new(episode: episode, integration: integration)
    end

    def increment_asset_wait
      self.class.update_status(integration, episode, asset_processing_attempts: (asset_processing_attempts || 0) + 1)
    end

    def reset_asset_wait
      self.class.update_status(integration, episode, asset_processing_attempts: 0)
    end

    def mark_as_uploaded!
      self.class.update_status(integration, episode, uploaded: true)
    end

    def mark_as_not_uploaded!
      self.class.update_status(integration, episode, uploaded: false)
    end

    # Whether the media file has been uploaded to the Integration
    # is a subset of whether the episode has been delivered
    def mark_as_delivered!
      self.class.update_status(integration, episode, delivered: true, uploaded: true, asset_processing_attempts: 0)
    end

    def mark_as_not_delivered!
      self.class.update_status(integration, episode, delivered: false, uploaded: false)
    end
  end
end
