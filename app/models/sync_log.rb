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

  def complete?
    updated_at.present? && external_id.present?
  end

  def self.log!(attrs)
    integration = attrs.delete(:integration)
    feeder_type = attrs.delete(:feeder_type)
    feeder_id = attrs.delete(:feeder_id)
    external_id = attrs.delete(:external_id)
    api_response = attrs.delete(:api_response)

    sync_log = SyncLog.find_or_initialize_by(
      integration: integration,
      feeder_type: feeder_type,
      feeder_id: feeder_id,
      external_id: external_id
    )
    sync_log.update!(api_response: api_response, updated_at: Time.now.utc)
    sync_log
  end
end
