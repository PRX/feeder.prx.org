module Integrations
  class EpisodeDeliveryStatus < ApplicationRecord
    self.inheritance_column = :integration

    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"

    enum :integration, Integrations::INTEGRATIONS

    INTEGRATION_CLASSES = {
      "apple" => "Apple::EpisodeDeliveryStatus",
      "megaphone" => "Megaphone::EpisodeDeliveryStatus"
    }.freeze

    def self.find_sti_class(type_name)
      integration = base_class.type_for_attribute(inheritance_column).cast(type_name)
      INTEGRATION_CLASSES.fetch(integration).constantize
    end

    def self.measure_asset_processing_duration(episode_delivery_statuses)
      # Relies on episode_delivery_statuses being ordered by created_at DESC
      # (enforced by association: has_many :episode_delivery_statuses, -> { order(created_at: :desc) })
      statuses = episode_delivery_statuses.to_a

      latest_status = statuses.shift
      return nil unless latest_status&.asset_processing_attempts.to_i.positive?

      # Find the most recent status where asset processing started (attempts == 0)
      start_status = statuses.find { |status| status.asset_processing_attempts.to_i.zero? }
      return nil unless start_status

      # Measure from start to the latest status creation time
      Time.now.utc - start_status.created_at
    end

    def self.update_status(integration, episode, attrs)
      reject_unscoped_apple!(integration)
      new_status = episode.episode_delivery_status(integration)&.dup || default_status(integration, episode)
      new_status.assign_attributes(attrs.merge(integration: integration))
      new_status.save!
      episode.episode_delivery_statuses.reset
      new_status
    end

    def self.delete_status(integration, episode)
      reject_unscoped_apple!(integration)
      episode.episode_delivery_statuses.where(integration: integration).delete_all
    end

    def self.default_status(integration, episode)
      reject_unscoped_apple!(integration)
      new(episode: episode, integration: integration)
    end

    # Apple delivery state must be accessed through the show-scoped
    # Apple::Episode facade, which supplies the Apple show ID.
    def self.reject_unscoped_apple!(integration)
      return unless integration.to_s == "apple"

      raise Apple::MissingShowIdentityError, "Apple delivery state requires Apple::EpisodeDeliveryStatus and a show ID"
    end
    private_class_method :reject_unscoped_apple!

    def needs_upload?
      !uploaded || needs_media_version?
    end

    def has_media_version?
      MediaVersion.matches_current_id?(source_media_version_id, episode.media_version_id)
    end

    def needs_media_version?
      !has_media_version?
    end
  end
end
