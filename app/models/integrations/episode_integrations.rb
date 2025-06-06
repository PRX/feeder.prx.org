require "active_support/concern"

module Integrations::EpisodeIntegrations
  extend ActiveSupport::Concern

  included do
    has_many :episode_delivery_statuses, -> { order(created_at: :desc) }, class_name: "Integrations::EpisodeDeliveryStatus"
    has_many :sync_logs, -> { episodes }, foreign_key: "feeder_id"

    scope :unfinished, ->(integration) do
      int = Integrations::EpisodeDeliveryStatus.integrations[integration]
      frag = <<~SQL
        left join lateral (
          select "integrations_episode_delivery_statuses".*
          from "integrations_episode_delivery_statuses"
          where "episodes"."id" = "integrations_episode_delivery_statuses"."episode_id"
          order by "integrations_episode_delivery_statuses"."created_at" desc
          limit 1
        ) eds on true
      SQL
      joins(frag)
        .where('("eds"."episode_id" is null) or (("eds"."delivered" = false or "eds"."uploaded" = false) and "eds"."integration" = ?)', int)
    end
  end

  def publish_to_integration?(integration)
    # see if there is an integration
    podcast.feeds.any? { |f| f.integration_type == integration && f.publish_integration? }
  end

  def sync_log(integration)
    sync_logs.send(integration.intern).order(updated_at: :desc).first
  end

  def episode_delivery_status(integration, with_default = false)
    status = episode_delivery_statuses.reset.order(created_at: :desc).send(integration.intern).first
    if !status && with_default
      Integrations::EpisodeDeliveryStatus.default_status(integration, self)
    else
      status
    end
  end

  def update_episode_delivery_status(integration, attrs)
    Integrations::EpisodeDeliveryStatus.update_status(integration, self, attrs)
  end

  def delete_episode_delivery_status(integration)
    Integrations::EpisodeDeliveryStatus.delete_status(integration, self)
  end
end
