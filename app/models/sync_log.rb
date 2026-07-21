class SyncLog < ApplicationRecord
  self.inheritance_column = :integration

  enum :integration, Integrations::INTEGRATIONS

  INTEGRATION_CLASSES = {
    "apple" => "Apple::SyncLog",
    "megaphone" => "SyncLog"
  }.freeze

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

  def self.find_sti_class(type_name)
    integration = base_class.type_for_attribute(inheritance_column).cast(type_name)
    INTEGRATION_CLASSES.fetch(integration).constantize
  end

  def self.log!(attrs)
    integration = attrs.delete(:integration)
    feeder_type = attrs.delete(:feeder_type)
    feeder_id = attrs.delete(:feeder_id)
    external_id = attrs.delete(:external_id)
    api_response = attrs.delete(:api_response)
    apple_show_id = attrs.delete(:apple_show_id)

    identity = {
      integration: integration,
      feeder_type: feeder_type,
      feeder_id: feeder_id,
      apple_show_id: apple_show_id
    }
    sync_log = SyncLog.find_or_initialize_by(identity)

    # TODO remove with cutover once no legacy NULL-show Apple episode rows remain.
    if apple_show_id.present? && sync_log.new_record?
      legacy_sync_log = SyncLog.find_by(
        **identity.except(:apple_show_id),
        external_id: external_id,
        apple_show_id: nil
      )

      if legacy_sync_log
        sync_log = legacy_sync_log
        sync_log.apple_show_id = apple_show_id
      end
    end

    sync_log.update!(external_id: external_id, api_response: api_response, updated_at: Time.now.utc)
    sync_log
  end
end
