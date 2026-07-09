class SyncLog < ApplicationRecord
  enum :integration, Integrations::INTEGRATIONS

  # kinda like an AR polymorphic relation, but not using that
  enum :feeder_type, {
    # common
    feeds: "feeds",
    episodes: "episodes",
    # apple
    podcast_containers: "containers",
    podcast_deliveries: "deliveries",
    podcast_delivery_files: "delivery_files"
  }

  scope :latest, -> do
    joins("JOIN LATERAL ( SELECT max(id) as max_id
                          FROM sync_logs
                          GROUP BY integration, feeder_type, feeder_id, external_id  ) q
                          ON id = max_id")
  end

  serialize :api_response, coder: JSON

  # TODO: Convert to AR polymorphism,
  # this is a hack to validate Apple::Episode concerns:
  validates :feeder_id,
    uniqueness: {
      scope: [:integration, :feeder_type],
      message: "already has an Apple episode sync log"
    },
    if: :apple_episode_sync_log?
  validates :apple_show_id, presence: true, if: :apple_episode_sync_log?

  def complete?
    updated_at.present? && external_id.present?
  end

  def apple_episode_sync_log?
    apple? && episodes?
  end

  def self.log!(attrs)
    integration = attrs.delete(:integration)
    feeder_type = attrs.delete(:feeder_type)
    feeder_id = attrs.delete(:feeder_id)
    external_id = attrs.delete(:external_id)
    api_response = attrs.delete(:api_response)
    apple_show_id = attrs.delete(:apple_show_id)

    sync_log = SyncLog.find_or_initialize_by(
      integration: integration,
      feeder_type: feeder_type,
      feeder_id: feeder_id,
      external_id: external_id,
      apple_show_id: apple_show_id
    )

    # TODO: remove once writers are cut over and no NULL-show apple episode
    # rows remain (S10) — adopts pre-show-scoping rows instead of duplicating
    if apple_show_id.present? && sync_log.new_record?
      legacy_sync_log = SyncLog.find_by(
        integration: integration,
        feeder_type: feeder_type,
        feeder_id: feeder_id,
        external_id: external_id,
        apple_show_id: nil
      )

      if legacy_sync_log
        sync_log = legacy_sync_log
        sync_log.apple_show_id = apple_show_id
      end
    end

    sync_log.update!(api_response: api_response, updated_at: Time.now.utc)
    sync_log
  end
end
