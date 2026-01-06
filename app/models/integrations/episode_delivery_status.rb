module Integrations
  class EpisodeDeliveryStatus < ApplicationRecord
    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"

    enum :integration, Integrations::INTEGRATIONS

    def self.measure_asset_processing_duration(episode_delivery_statuses)
      # Relies on episode_delivery_statuses being ordered by created_at DESC
      # (enforced by association: has_many :episode_delivery_statuses, -> { order(created_at: :desc) })
      statuses = episode_delivery_statuses.to_a

      # Only measure if currently processing
      return nil unless statuses.first&.asset_processing_attempts.to_i.positive?

      # Get statuses from current upload cycle (stop at any previous delivered status)
      current_cycle = statuses.take_while { |s| !s.delivered? }

      # Find when upload completed in this cycle (oldest uploaded status)
      upload_completed = current_cycle.select(&:uploaded?).last
      return nil unless upload_completed

      Time.current - upload_completed.created_at
    end

    def self.update_status(integration, episode, attrs)
      new_status = episode.episode_delivery_status(integration)&.dup || default_status(integration, episode)
      attrs[:integration] = integration
      new_status.assign_attributes(attrs)
      new_status.save!
      episode.episode_delivery_statuses.reset
      new_status
    end

    def self.delete_status(integration, episode)
      episode.episode_delivery_statuses.where(integration: integration).delete_all
    end

    def self.default_status(integration, episode)
      new(episode: episode, integration: integration)
    end

    def increment_asset_wait
      self.class.update_status(integration, episode, asset_processing_attempts: (asset_processing_attempts || 0) + 1)
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
